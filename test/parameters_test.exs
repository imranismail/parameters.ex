defmodule ParametersTest do
  use Parameters.Case
  use Parameters

  defmodule Haha do
    use Parameters
  end

  doctest Parameters

  @valid_params %{
    name: "Imran Ismail",
    gender: "male",
    password: "password123",
    password_confirmation: "password123",
    age: 27,
    terms_of_service: true,
    favourite_foods: ~w(waffle),
    email: "imran.codely@gmail.com",
    default_profile: %{
      provider: "github",
      username: "imranismail"
    },
    profiles: [
      %{
        provider: "github",
        username: "imranismail"
      }
    ]
  }

  @invalid_params %{}

  params do
    requires :name, :string, exclusion: ~w(anonymous Anonymous)
    requires :gender, :string, inclusion: ~w(male female)
    requires :password, :string, confirmation: [], length: [min: 8]
    requires :age, :integer, number: [greater_than: 18]
    requires :terms_of_service, :boolean, acceptance: []
    requires :favourite_foods, {:array, :string}, subset: ~w(pie waffle pancake)
    requires :email, :string, format: ~r/@/

    requires :profiles, :array do
      requires :provider, :string
      requires :username, :string
    end

    requires :default_profile, :map do
      requires :provider, :string
      requires :username, :string
    end
  end

  def controller_action_mock(conn, _params) do
    conn
  end

  params do
    requires :another_field, :string
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
    assert module_defined?(Parameters.ParametersTest.ControllerActionMock.DefaultProfile)
    assert module_defined?(Parameters.ParametersTest.ControllerActionMock.Profiles)
  end

  test "Parameters.params_for/1 should validate parameters" do
    conn = phoenix_conn(ParametersTest, :controller_action_mock)
    assert {:ok, params} = Parameters.params_for(%{conn | params: @valid_params})
    assert {:error, %Ecto.Changeset{}} = Parameters.params_for(%{conn | params: @invalid_params})
  end

  test "Parameters.changeset_for/1 should return changeset" do
    conn = phoenix_conn(ParametersTest, :controller_action_mock)
    assert %Ecto.Changeset{} = Parameters.changeset_for(%{conn | params: @valid_params})
  end

  test "Schemas are different for each action" do
    conn = phoenix_conn(ParametersTest, :controller_action_mock)
    assert {:ok, params} = Parameters.params_for(%{conn | params: @valid_params})

    conn = phoenix_conn(ParametersTest, :another_controller_action_mock)
    assert {:error, %Ecto.Changeset{}} = Parameters.params_for(%{conn | params: @invalid_params})
  end

  test "Changeset.validate_format declaration" do
    conn = phoenix_conn(ParametersTest, :controller_action_mock)
    invalid_params = Map.put(@valid_params, :email, "invalidformat")

    assert {:error, changeset} = Parameters.params_for(%{conn | params: invalid_params})
  end

  test "Changeset.validate_length declaration" do
    conn = phoenix_conn(ParametersTest, :controller_action_mock)
    invalid_params = Map.put(@valid_params, :password, "2short")

    assert {:error, changeset} = Parameters.params_for(%{conn | params: invalid_params})
  end

  test "Changeset.validate_subset declaration" do
    conn = phoenix_conn(ParametersTest, :controller_action_mock)
    invalid_params = Map.put(@valid_params, :favourite_foods, ["not", "in", "subset"])

    assert {:error, changeset} = Parameters.params_for(%{conn | params: invalid_params})
  end

  test "Changeset.validate_inclusion declaration" do
    conn = phoenix_conn(ParametersTest, :controller_action_mock)
    invalid_params = Map.put(@valid_params, :gender, "not included")

    assert {:error, changeset} = Parameters.params_for(%{conn | params: invalid_params})
  end

  test "Changeset.validate_acceptance declaration" do
    conn = phoenix_conn(ParametersTest, :controller_action_mock)
    invalid_params = Map.put(@valid_params, :terms_of_service, false)

    assert {:error, changeset} = Parameters.params_for(%{conn | params: invalid_params})
  end

  test "Changeset.validate_confirmation declaration" do
    conn = phoenix_conn(ParametersTest, :controller_action_mock)
    invalid_params = Map.delete(@valid_params, :password_confirmation)

    assert {:error, changeset} = Parameters.params_for(%{conn | params: invalid_params})
  end

  test "Changeset.validate_exclusion declaration" do
    conn = phoenix_conn(ParametersTest, :controller_action_mock)
    invalid_params = Map.put(@valid_params, :name, "Anonymous")

    assert {:error, changeset} = Parameters.params_for(%{conn | params: invalid_params})
  end

  test "Changeset.validate_number declaration" do
    conn = phoenix_conn(ParametersTest, :controller_action_mock)
    invalid_params = Map.put(@valid_params, :age, 18)

    assert {:error, changeset} = Parameters.params_for(%{conn | params: invalid_params})
  end
end
