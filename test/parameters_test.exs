defmodule ParametersTest do
  use ExUnit.Case
  doctest Parameters

  defmodule ControllerMock do
    use Parameters

    params do
      requires :root_req, :string
      optional :root_opt, :integer

      requires :profile, :map do
        requires :in_group_req, :string
        optional :in_group_opt, :string
      end

      requires :profiles, :array do
        requires :oneline, :string
      end
    end

    def create(conn, _params) do
      with {:ok, params} <- params_for(conn) do
        params
      end
    end
  end

  test "expects Ecto.Changeset when params_for/1 or params_for/2" do
    params = %{}

    conn = %{
      params: params,
      private: %{phoenix_controller: ParametersTest.ControllerMock, phoenix_action: :create}
    }

    assert {:error, %Ecto.Changeset{}} = ParametersTest.ControllerMock.create(conn, params)
  end
end
