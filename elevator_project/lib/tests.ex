defmodule Test do
  def compare_backups() do
    map1 = [:cab => 1, :hall_down => [1], :hall_up => [1]]
    map2 = [:cab => 1, :hall_down => [1], :hall_up => [1]]
    map3 = [:cab => 3, :hall_down => [1], :hall_up => [1]]
    map4 = [:cab => 1, :hall_down => [1], :hall_up => [2]]
    map = [map1, map2, map3, map4]
    OrderDistributor.compare_backups(map)
  end
end