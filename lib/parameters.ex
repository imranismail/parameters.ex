defmodule Parameters do
  alias Parameters.{
    ParamsNode,
    FieldNode
  }

  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)

      @on_definition Parameters
      @before_compile Parameters

      Module.register_attribute(__MODULE__, :parameters, accumulate: true)
    end
  end

  def __on_definition__(%{module: module}, _kind, name, _args, _guards, _body) do
    if ast = Module.get_attribute(module, :parameters_block) do
      Module.put_attribute(module, :parameters, ParamsNode.parse(name, ast))
      Module.delete_attribute(module, :parameters_block)
    end
  end

  defmacro __before_compile__(env) do
    quote do
      unquote(define_schemas(env.module))
      unquote(define_reflections())
    end
  end

  defmacro params(do: block) do
    quote do
      @parameters_block unquote(Macro.escape(block, prune_metadata: true))
    end
  end

  def params_for(module, fun, params) do
    module
    |> changeset_for(fun, params)
    |> params_for()
  end

  def params_for(%Ecto.Changeset{} = changeset) do
    with {:ok, schema} <- Ecto.Changeset.apply_action(changeset, :insert) do
      {:ok, schema_to_map(schema)}
    end
  end

  def params_for(%{
        private: %{phoenix_controller: module, phoenix_action: fun},
        params: params
      }) do
    params_for(module, fun, params)
  end

  def changeset_for(module, fun, params) do
    module = Module.safe_concat([Parameters, module, Macro.camelize("#{fun}")])
    apply(module, :changeset, [struct(module), params])
  end

  def changeset_for(%{
        private: %{phoenix_controller: module, phoenix_action: fun},
        params: params
      }) do
    changeset_for(module, fun, params)
  end

  defp define_reflections() do
    quote do
      def __parameters__ do
        @parameters
      end
    end
  end

  defp define_schemas(module) do
    parameters = Module.get_attribute(module, :parameters)
    parent = Module.concat(Parameters, module)

    for schema <- parameters do
      quote do
        unquote(define_schema(parent, schema))
      end
    end
  end

  defp define_schema(parent, node) do
    module = Module.concat(parent, Macro.camelize("#{node.id}"))

    quote do
      defmodule unquote(module) do
        use Ecto.Schema

        @primary_key false

        embedded_schema do
          unquote(define_fields(node.fields))
        end

        unquote(define_changeset(node.fields))

        unquote(define_embeds(module, node.fields))
      end
    end
  end

  defp define_embeds(parent, fields) do
    for field <- fields, not is_nil(field.fields) do
      define_schema(parent, field)
    end
  end

  defp define_fields(fields) do
    for field <- fields do
      options = Keyword.take(field.options, [:default])

      case field do
        %FieldNode{type: :map, fields: fields} when is_list(fields) ->
          quote do
            embeds_one unquote(field.id),
                       Module.concat(__MODULE__, Macro.camelize("#{unquote(field.id)}")),
                       unquote(options)
          end

        %FieldNode{type: :array, fields: fields} when is_list(fields) ->
          quote do
            embeds_many unquote(field.id),
                        Module.concat(__MODULE__, Macro.camelize("#{unquote(field.id)}")),
                        unquote(options)
          end

        %FieldNode{fields: nil} ->
          quote do
            field unquote(field.id), unquote(field.type), unquote(options)
          end
      end
    end
  end

  defp define_changeset(fields) do
    permitted_fields =
      fields
      |> Enum.filter(fn field -> is_nil(field.fields) end)
      |> Enum.map(fn field -> field.id end)

    required_fields =
      fields
      |> Enum.filter(fn field ->
        is_nil(field.fields) and Keyword.fetch!(field.options, :required)
      end)
      |> Enum.map(fn field -> field.id end)

    optional_embeds =
      fields
      |> Enum.filter(fn field ->
        not is_nil(field.fields) and not Keyword.fetch!(field.options, :required)
      end)
      |> Enum.map(fn field -> field.id end)

    required_embeds =
      fields
      |> Enum.filter(fn field ->
        not is_nil(field.fields) and Keyword.fetch!(field.options, :required)
      end)
      |> Enum.map(fn field -> field.id end)

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
