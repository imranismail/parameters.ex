defmodule ParameterTest do
  use ExUnit.Case
  doctest Parameter

  test "greets the world" do
    assert Parameter.hello() == :world
  end
end
