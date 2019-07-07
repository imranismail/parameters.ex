defmodule ParametersTest do
  use Parameters.Case
  use Parameters

  doctest Parameters

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

  def controller_action_mock(conn, _params) do
    conn
  end

  params do
    requires :nope_nope, :string
  end

  def another_controller_action_mock(conn, _params) do
    conn
  end

  test "Parameters are namespaced" do
    assert not module_defined?(ParametersTest.ControllerActionMock)
    assert module_defined?(Parameters.ParametersTest.ControllerActionMock)
  end

  test "Parameters are defined per action" do
    assert module_defined?(Parameters.ParametersTest.AnotherControllerActionMock)
  end

  test "Parameters should be nestable like Ecto's inline embeds" do
    assert module_defined?(Parameters.ParametersTest.ControllerActionMock.Profile)
    assert module_defined?(Parameters.ParametersTest.ControllerActionMock.Profile.Tendencies)
    assert module_defined?(Parameters.ParametersTest.ControllerActionMock.Profiles)
  end

  test "Schema.params_for/1 should validate parameters" do
    conn = phoenix_conn(ParametersTest, :controller_action_mock)

    assert {:ok, params} = Parameters.params_for(%{conn | params: @valid_params})
    assert {:error, %Ecto.Changeset{}} = Parameters.params_for(%{conn | params: @invalid_params})
  end

  test "Schema.changeset_for/1 should return changeset" do
    conn = phoenix_conn(ParametersTest, :controller_action_mock)

    assert %Ecto.Changeset{} = Parameters.changeset_for(%{conn | params: @valid_params})
  end

  test "Schemas are different for each action" do
    conn = phoenix_conn(ParametersTest, :controller_action_mock)
    assert {:ok, params} = Parameters.params_for(%{conn | params: @valid_params})

    conn = phoenix_conn(ParametersTest, :another_controller_action_mock)
    assert {:error, %Ecto.Changeset{}} = Parameters.params_for(%{conn | params: @invalid_params})
  end
end