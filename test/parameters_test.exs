defmodule ParametersTest do
  use ExUnit.Case
  doctest Parameters

  defmodule ControllerMock do
    use Parameters

    params do
      requires :root_req, :string, default: "required"
      optional :root_opt, :integer

      requires :profile, :map do
        requires :in_group_req, :string
        optional :in_group_opt, :string

        optional :tendencies, :array do
          optional :name, :string
          optional :dunno, :string
        end
      end

      requires :profiles, :array do
        requires :oneline, :string
      end
    end

    def create(conn, _params) do
      conn
    end
  end

  @valid_params %{
    root_opt: 1,
    profile: %{
      in_group_req: "required",
      in_group_opt: "optional"
    },
    profiles: [
      %{oneline: "required"}
    ]
  }

  @invalid_params %{}

  test "Schema.params_for/1" do
    conn = %{
      params: nil,
      private: %{phoenix_controller: ParametersTest.ControllerMock, phoenix_action: :create}
    }

    assert {:ok, params} = Parameters.params_for(%{conn | params: @valid_params})
    assert {:error, %Ecto.Changeset{}} = Parameters.params_for(%{conn | params: @invalid_params})
  end
end
