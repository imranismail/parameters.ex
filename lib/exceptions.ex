defmodule Parameters.InvalidError do
  defexception [:changeset, plug_status: 400]

  def message(value) do
    """
    Invalid parameters

      #{inspect(error_messages(value.changeset))}
    """
  end

  defp error_messages(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
