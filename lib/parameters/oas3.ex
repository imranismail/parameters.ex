defmodule Parameters.OAS3 do
  def type_mapper(:map), do: :object
  def type_mapper(:integer), do: :number
  def type_mapper(:float), do: :number
  def type_mapper(any), do: any

  defmacro __using__(opts) do
    version = Keyword.fetch!(opts, :version)
    title = Keyword.fetch!(opts, :title)
    content_types = Keyword.fetch!(opts, :content_types)
    accepts = Keyword.fetch!(opts, :accepts)

    quote do
      def generate do
        config = Application.get_env(unquote(opts[:otp_app]), __MODULE__)
        router = Keyword.fetch!(config, :router)
        routes = router.__routes__()
        accepts = unquote(accepts)
        content_types = unquote(content_types)

        spec = %{
          openapi: "3.0.0",
          info: %{
            title: unquote(title),
            version: unquote(version)
          }
        }

        key_fn = fn route -> route.path end
        val_fn = fn route ->
          parameters = route.plug.__parameters__()
          node = Enum.find(parameters, fn node -> node.id == route.plug_opts end)

          key = "#{route.verb}"
          val = %{
            requestBody: %{
              required: true,
              description: "",
              content: for pipeline <- route.pipe_through, into: %{} do
                key = Keyword.fetch!(content_types, pipeline)

                val = %{
                  schema: %{
                    required: for field <- node.fields, field.options[:required] do
                      field.id
                    end,
                    properties: for field <- node.fields, into: %{} do
                      {field.id, %{
                        type: Parameters.OpenAPI.type_mapper(field.type)
                      }}
                    end,
                  }
                }

                {key, val}
              end,
            },
            responses: %{
              default: %{
                description: "",
                content: for pipeline <- route.pipe_through, into: %{} do
                  key = Keyword.fetch!(content_types, pipeline)

                  val = %{
                    schema: %{
                      type: :object
                    }
                  }

                  {key, val}
                end,
              }
            },
          }

          {key, val}
        end

        paths =
          routes
          |> Enum.group_by(key_fn, val_fn)
          |> Enum.map(fn {key, val} -> {key, Enum.into(val, %{})} end)
          |> Enum.into(%{})

        Map.put(spec, :paths, paths)
      end
    end
  end
end