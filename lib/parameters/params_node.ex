defmodule Parameters.ParamsNode do
  defstruct [
    :id,
    fields: []
  ]

  def parse(name, {:__block__, _metadata, ast}), do: parse(name, ast)
  def parse(name, ast) when is_tuple(ast), do: parse(name, [ast])

  def parse(name, ast) when is_list(ast) do
    Enum.reduce(ast, struct(__MODULE__), fn field, schema ->
      Map.update!(schema, :fields, fn fields ->
        [Parameters.FieldNode.parse(field) | fields]
      end)
    end)
    |> Map.put(:id, name)
    |> Map.update!(:fields, &Enum.reverse/1)
  end
end
