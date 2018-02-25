defmodule LibclusterConsulTest do
  use ExUnit.Case
  doctest LibclusterConsul

  test "greets the world" do
    assert LibclusterConsul.hello() == :world
  end
end
