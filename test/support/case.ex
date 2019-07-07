defmodule Parameters.Case do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Parameters.Case, only: [phoenix_conn: 2, module_defined?: 1]
    end
  end

  def phoenix_conn(controller, action) do
    %{
      params: nil,
      private: %{phoenix_controller: controller, phoenix_action: action}
    }
  end

  def module_defined?(module) do
    function_exported?(module, :__info__, 1)
  end
end


