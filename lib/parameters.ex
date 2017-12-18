defmodule Parameters do
  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :params, accumulate: true)

      @before_compile unquote(__MODULE__)
    end
  end

  def from_schema(schema) do
    schema
    |> Map.from_struct()
    |> Enum.reduce(%{}, fn
      {key, %_struct{__meta__: _} = schema}, acc ->
        Map.put(acc, key, from_schema(schema))
      {key, val}, acc ->
        Map.put(acc, key, val)
    end)
  end

  defmacro __before_compile__(env) do
    for {action, module} <- Module.get_attribute(env.module, :params) do
      quote do
        defp __changeset__(action, schema, params) do
          groups    = schema.__struct__.__params__(:groups)
          optional  = schema.__struct__.__params__(:optional)
          required  = schema.__struct__.__params__(:required)

          changeset =
            schema
            |> Ecto.Changeset.cast(params, optional ++ required)
            |> Ecto.Changeset.validate_required(required)

          Enum.reduce(groups, changeset, fn {key, opts}, changeset ->
            opts = Keyword.put_new(opts, :with, fn schema, params ->
              __changeset__(action, schema, params)
            end)

            Ecto.Changeset.cast_embed(changeset, key, opts)
          end)
        end

        defp __params__(conn, unquote(action)) do
          if conn.private.phoenix_action == unquote(action) do
            changeset = __changeset__(unquote(action), struct(unquote(module)), conn.params)

            if changeset.valid? do
              params =
                changeset
                |> Ecto.Changeset.apply_changes()
                |> Parameters.from_schema()

              %{conn | params: params}
            else
              raise Parameters.InvalidError, changeset: %{changeset | action: :parameters}
            end
          else
            conn
          end
        end
      end
    end
  end

  defmacro params(action, do: block) do
    quote do
      module = Module.concat(__MODULE__, Macro.camelize("#{unquote(action)}"))

      @action module

      @params {unquote(action), module}

      plug :__params__, unquote(action)

      defmodule module do
        use Ecto.Schema

        @primary_key false

        Module.register_attribute __MODULE__, :required, accumulate: true
        Module.register_attribute __MODULE__, :optional, accumulate: true
        Module.register_attribute __MODULE__, :groups, accumulate: true

        embedded_schema do
          unquote(block)
        end

        def __params__(:required), do: @required
        def __params__(:optional), do: @optional
        def __params__(:groups), do: @groups
      end
    end
  end

  defmacro requires(field, type) do
    quote do
      @required unquote(field)
      field unquote(field), unquote(type)
    end
  end

  defmacro optional(field, type) do
    quote do
      @optional unquote(field)
      field unquote(field), unquote(type)
    end
  end

  defmacro group(field, do: block) do
    quote do
      @groups {unquote(field), []}

      params unquote(field) do
        unquote(block)
      end

      embeds_one unquote(field), Module.concat(__MODULE__, Macro.camelize("#{unquote(field)}"))
    end
  end

  defmacro group(field, opts, do: block) when is_list(opts) do
    quote do
      @groups {unquote(field), unquote(opts)}

      params unquote(field) do
        unquote(block)
      end

      embeds_one unquote(field), Module.concat(__MODULE__, Macro.camelize("#{unquote(field)}"))
    end
  end
end
