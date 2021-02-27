defmodule ELEVATOR_SYSTEMTest do
  use ExUnit.Case
  doctest ELEVATOR_SYSTEM

  test "greets the world" do
    assert ELEVATOR_SYSTEM.hello() == :world
  end
end
