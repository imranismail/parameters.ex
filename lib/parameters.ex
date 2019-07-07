defmodule Parameters do
  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)

      @on_definition Parameters
      @before_compile Parameters

      Module.register_attribute(__MODULE__, :parameters, accumulate: true)
    end
  end

  def __on_definition__(%{module: module}, _kind, name, _args, _guards, _body) do
    if nodes = Module.get_attribute(module, :parameters_block) do
      name = Module.concat([Parameters, module, Macro.camelize("#{name}")])
      Module.put_attribute(module, :parameters, {name, nodes})
      Module.delete_attribute(module, :parameters_block)
    end
  end

  defmacro __before_compile__(env) do
    for {name, nodes} <- Module.get_attribute(env.module, :parameters) do
      quote do
        unquote(define_schema(name, nodes))
      end
    end
  end

  defmacro params(do: block) do
    quote do
      @parameters_block unquote(Macro.escape(block))
    end
  end

  def params_for(controller, action, params) do
    controller
    |> changeset_for(action, params)
    |> params_for()
  end

  def params_for(%Ecto.Changeset{} = changeset) do
    with {:ok, schema} <- Ecto.Changeset.apply_action(changeset, :insert) do
      {:ok, schema_to_map(schema)}
    end
  end

  def params_for(%{
        private: %{phoenix_controller: controller, phoenix_action: action},
        params: params
      }) do
    params_for(controller, action, params)
  end

  def changeset_for(controller, action, params) do
    name = Module.safe_concat([Parameters, controller, Macro.camelize("#{action}")])
    apply(name, :changeset, [struct(name), params])
  end

  def changeset_for(%{
        private: %{phoenix_controller: controller, phoenix_action: action},
        params: params
      }) do
    changeset_for(controller, action, params)
  end

  defp define_fields({:__block__, _metadata, nodes}), do: define_fields(nodes)
  defp define_fields(node) when is_tuple(node), do: define_fields([node])

  defp define_fields(nodes) when is_list(nodes) do
    field_definitions =
      for {_name, _metadata, args} <- nodes do
        case args do
          [field, :map, [do: _defs]] ->
            quote do
              embeds_one unquote(field),
                         Module.concat(__MODULE__, Macro.camelize("#{unquote(field)}"))
            end

          [field, :array, [do: _defs]] ->
            quote do
              embeds_many unquote(field),
                          Module.concat(__MODULE__, Macro.camelize("#{unquote(field)}"))
            end

          [field, type] ->
            quote do
              field unquote(field), unquote(type)
            end

          [field, type, opts] ->
            quote do
              field unquote(field), unquote(type), unquote(opts)
            end
        end
      end

    quote do
      use Ecto.Schema

      @primary_key false

      embedded_schema do
        unquote(field_definitions)
      end
    end
  end

  defp define_changeset({:__block__, _metadata, nodes}), do: define_changeset(nodes)
  defp define_changeset(node) when is_tuple(node), do: define_changeset([node])

  defp define_changeset(nodes) when is_list(nodes) do
    key_fn = fn
      {:requires, _metadata, [_field, _type, do: _defs]} -> :required_embeds
      {:requires, _metadata, [_field, _type, [do: _defs]]} -> :required_embeds
      {:optional, _metadata, [_field, _type, do: _defs]} -> :optional_embeds
      {:optional, _metadata, [_field, _type, [do: _defs]]} -> :optional_embeds
      {:requires, _metadata, _args} -> :required_fields
      {:optional, _metadata, _args} -> :optional_fields
    end

    value_fn = fn
      {_name, _metadata, [field, _type]} -> {field, []}
      {_name, _metadata, [field, _type, opts]} -> {field, opts}
    end

    fields = Enum.group_by(nodes, key_fn, value_fn)

    required_fields = Map.get(fields, :required_fields, [])

    permitted_fields =
      fields
      |> Map.get(:optional_fields, [])
      |> Enum.concat(required_fields)
      |> Enum.map(&Kernel.elem(&1, 0))

    required_fields = Enum.map(required_fields, &Kernel.elem(&1, 0))

    optional_embeds =
      fields
      |> Map.get(:optional_embeds, [])
      |> Enum.map(&Kernel.elem(&1, 0))

    required_embeds =
      fields
      |> Map.get(:required_embeds, [])
      |> Enum.map(&Kernel.elem(&1, 0))

    quote do
      def changeset(schema, params) do
        changeset =
          schema
          |> Ecto.Changeset.cast(params, unquote(permitted_fields))
          |> Ecto.Changeset.validate_required(unquote(required_fields))

        changeset =
          Enum.reduce(unquote(optional_embeds), changeset, fn item, acc ->
            Ecto.Changeset.cast_embed(acc, item)
          end)

        changeset =
          Enum.reduce(unquote(required_embeds), changeset, fn item, acc ->
            Ecto.Changeset.cast_embed(acc, item, required: true)
          end)

        changeset
      end
    end
  end

  defp define_embeds(name, {:__block__, _metadata, nodes}), do: define_embeds(name, nodes)
  defp define_embeds(name, node) when is_tuple(node), do: define_embeds(name, [node])

  defp define_embeds(name, nodes) when is_list(nodes) do
    nodes
    |> Enum.filter(fn
      {_name, _metadata, [_field, _type, do: _defs]} -> true
      {_name, _metadata, [_field, _type, [do: _defs]]} -> true
      _ -> false
    end)
    |> Enum.map(fn
      {_name, _metadata, [field, _type, do: nodes]} ->
        name = Module.concat(name, Macro.camelize("#{field}"))
        define_schema(name, nodes)

      {_name, _metadata, [field, _type, [do: nodes]]} ->
        name = Module.concat(name, Macro.camelize("#{field}"))
        define_schema(name, nodes)
    end)
  end

  defp define_schema(name, {:__block__, _metadata, nodes}), do: define_schema(name, nodes)
  defp define_schema(name, node) when is_tuple(node), do: define_schema(name, [node])

  defp define_schema(name, nodes) when is_list(nodes) do
    quote do
      defmodule unquote(name) do
        unquote(define_embeds(name, nodes))

        unquote(define_fields(nodes))

        unquote(define_changeset(nodes))
      end
    end
  end

  defp schema_to_map(nil), do: nil
  defp schema_to_map(schemas) when is_list(schemas), do: Enum.map(schemas, &schema_to_map/1)

  defp schema_to_map(%module{} = schema) do
    embeds = module.__schema__(:embeds)

    mapper = fn {key, val} ->
      if key in embeds do
        {key, schema_to_map(val)}
      else
        {key, val}
      end
    end

    schema
    |> Map.from_struct()
    |> Enum.map(mapper)
    |> Enum.into(%{})
  end
end
