defmodule Parameters do
  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)

      @on_definition {Parameters, :define}
      @before_compile {Parameters, :compile}

      Module.register_attribute(__MODULE__, :parameters, accumulate: true)
    end
  end

  def define(%{module: module}, _kind, name, _args, _guards, _body) do
    ast = Module.get_attribute(module, :parameters_block)
    Module.put_attribute(module, :parameters, {name, ast})
    Module.delete_attribute(module, :parameters_block)
  end

  def required_fields({:__block__, _metadata, nodes}), do: required_fields(nodes)
  def required_fields(node) when is_tuple(node), do: required_fields([node])

  def required_fields(nodes) when is_list(nodes) do
    for {name, _metadata, args} <- nodes, name == :requires do
      case args do
        [field, _type, [do: _defs]] ->
          {:embed, field, []}

        [field, _type, opts] ->
          {:field, field, opts}

        [field, _type] ->
          {:field, field, []}
      end
    end
  end

  def optional_fields({:__block__, _metadata, nodes}), do: optional_fields(nodes)
  def optional_fields(node) when is_tuple(node), do: optional_fields([node])

  def optional_fields(nodes) when is_list(nodes) do
    for {name, _metadata, args} <- nodes, name == :optional do
      case args do
        [field, _type, [do: _defs]] ->
          {:embed, field, []}

        [field, _type, opts] ->
          {:field, field, opts}

        [field, _type] ->
          {:field, field, []}
      end
    end
  end

  def schema_fields({:__block__, _metadata, nodes}), do: schema_fields(nodes)
  def schema_fields(node) when is_tuple(node), do: schema_fields([node])

  def schema_fields(nodes) when is_list(nodes) do
    for {_name, _metadata, args} <- nodes do
      case args do
        [field, :map, [do: defs]] ->
          quote do
            embeds_one unquote(field), unquote(Macro.camelize("#{field}")) do
              unquote(schema_fields(defs))
            end
          end

        [field, :array, [do: defs]] ->
          quote do
            embeds_many unquote(field), unquote(Macro.camelize("#{field}")) do
              unquote(schema_fields(defs))
            end
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
  end

  defmacro compile(env) do
    for {action, ast} <- Module.get_attribute(env.module, :parameters) do
      module = Module.concat([env.module, Parameters, Macro.camelize("#{action}")])
      fields = schema_fields(ast)
      required_fields = required_fields(ast)
      optional_fields = optional_fields(ast)

      quote do
        defmodule unquote(module) do
          use Ecto.Schema

          embedded_schema do
            unquote(fields)
          end

          def build(params) do
            changeset =
              __MODULE__
              |> struct()
              |> Ecto.Changeset.change()

            changeset =
              Enum.reduce(__parameters__(:optional), changeset, fn {type, field, _opts}, acc ->
                case type do
                  :field ->
                    Ecto.Changeset.cast(acc, params, [field])

                  :embed ->
                    Ecto.Changeset.cast_embed(acc, field, required: false)
                end
              end)

            changeset =
              Enum.reduce(__parameters__(:required), changeset, fn {type, field, _opts}, acc ->
                case type do
                  :field ->
                    acc
                    |> Ecto.Changeset.cast(params, [field])
                    |> Ecto.Changeset.validate_required(field)

                  :embed ->
                    Ecto.Changeset.cast_embed(acc, field, required: true)
                end
              end)

            changeset
          end

          def __parameters__(:required), do: unquote(Macro.escape(required_fields, []))
          def __parameters__(:optional), do: unquote(Macro.escape(optional_fields, []))
        end

        def __parameters__(:params, unquote(action), params) do
          __MODULE__
          |> changeset_for(unquote(action), params)
          |> params_for()
        end

        def __parameters__(:changeset, unquote(action), params) do
          apply(unquote(module), :build, [params])
        end
      end
    end
  end

  defmacro params(do: block) do
    quote do
      @parameters_block unquote(Macro.escape(block))
    end
  end

  def params_for(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.apply_action(changeset, :insert)
  end

  def params_for(%{
        private: %{phoenix_controller: controller, phoenix_action: action},
        params: params
      }) do
    controller.__parameters__(:params, action, params)
  end

  def params_for(controller, action, params) do
    controller.__parameters__(:params, action, params)
  end

  def changeset_for(controller, action, params) do
    controller.__parameters__(:changeset, action, params)
  end

  def changeset_for(%{
        private: %{phoenix_controller: controller, phoenix_action: action},
        params: params
      }) do
    controller.__parameters__(:changeset, action, params)
  end
end
