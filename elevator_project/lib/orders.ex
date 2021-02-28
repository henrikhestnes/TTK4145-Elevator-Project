defmodule Orders do
  use Agent

  @valid_order [:cab, :hall_down, :hall_up]

  def start_link do
    Agent.start_link(fn -> %{:cab => [], :hall_down => [], :hall_up => []} end, name: __MODULE__)
  end

  def new(floor, button_type) when is_integer(floor) and button_type in @valid_order do
    Agent.update(__MODULE__,
    fn map -> Map.update(map, button_type, [], fn list -> Enum.uniq([floor | list]) end) end)
  end

  def delete(floor, button_type) when is_integer(floor) and button_type in @valid_order do
    Agent.update(__MODULE__, fn map -> Map.update(map, button_type, [], fn list -> List.delete(list, floor) end) end)
  end

  def get do
    Agent.get(__MODULE__, fn orders -> orders end)
  end
  
end
