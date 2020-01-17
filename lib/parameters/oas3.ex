defmodule Parameters.OAS3 do
  def type_mapper(:map), do: :object
  def type_mapper(:integer), do: :number
  def type_mapper(:float), do: :number
  def type_mapper(any), do: any

  def render_paths(routes, content_types) do
    routes
    |> Enum.group_by(& &1.path, &render_operation(&1, content_types))
    |> Enum.map(fn {key, val} -> {key, Map.new(val)} end)
    |> Map.new()
  end

  def render_operation(route, content_types) do
    params = Enum.find(route.plug.__parameters__(), &(&1.id == route.plug_opts))
    fields = params && params.fields

    operation =
      Map.new()
      |> put_parameters(route, fields || [], content_types)
      |> put_default_response(route, content_types)

    {route.verb, operation}
  end

  def put_parameters(operation, %{verb: :get}, fields, _content_types) do
    parameters =
      for field <- fields do
        Map.new(
          in: "query",
          name: field.id,
          required: Keyword.get(field.opts, :required, false),
          schema: Map.new(type: type_mapper(field.type)),
          description: Keyword.get(field.opts, :description, "")
        )
      end

    Map.put(operation, :parameters, parameters)
  end

  def put_parameters(operation, route, fields, content_types) do
    req_body =
      Map.new(
        required: true,
        description: ""
      )

    content =
      for pipeline <- route.pipe_through,
          Map.has_key?(content_types, pipeline),
          into: Map.new() do
        content_type = Map.get(content_types, pipeline)

        required_fields =
          for field <- fields, Keyword.get(field.opts, :required, false) do
            field.id
          end

        properties =
          for field <- fields, into: Map.new() do
            {field.id, Map.new(type: type_mapper(field.type))}
          end

        example =
          for field <- fields, into: Map.new() do
            {field.id, type_mapper(field.type)}
          end

        content =
          Map.new(
            schema:
              Map.new(
                required: required_fields,
                properties: properties,
                example: example
              )
          )

        {content_type, content}
      end

    req_body = Map.put(req_body, :content, content)

    Map.put(operation, :requestBody, req_body)
  end

  def put_default_response(operation, _route, _content_types) do
    responses = Map.new(default: Map.new(description: "OK"))

    Map.put(operation, :responses, responses)
  end

  defmacro __using__(opts) do
    content_types = Keyword.fetch!(opts, :content_types)
    accepts = Keyword.fetch!(opts, :accepts)
    otp_app = Keyword.fetch!(opts, :otp_app)
    info = Keyword.fetch!(opts, :info)

    quote do
      @content_types Map.new(unquote(content_types))
      @accepts Map.new(unquote(accepts))
      @info Map.new(unquote(info))
      @otp_app unquote(otp_app)

      def render do
        routes = __parameters__(:routes)

        Map.new(
          openapi: "3.0.0",
          info: __parameters__(:info),
          paths: Parameters.OAS3.render_paths(routes, __parameters__(:content_types))
        )
      end

      def __parameters__(:info), do: @info
      def __parameters__(:accepts), do: @accepts
      def __parameters__(:content_types), do: @content_types

      def __parameters__(:routes) do
        config = Application.get_env(@otp_app, __MODULE__)

        config
        |> Keyword.fetch!(:router)
        |> apply(:__routes__, [])
        |> Enum.filter(fn route ->
          function_exported?(route.plug, :__parameters__, 0)
        end)
      end
    end
  end
end
