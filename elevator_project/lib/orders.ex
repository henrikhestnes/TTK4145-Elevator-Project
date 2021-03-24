defmodule Orders do
  use Agent

  @valid_order [:cab, :hall_down, :hall_up]

  # API
  def start_link do
    Agent.start_link(fn -> %{:cab => [], :hall_down => [], :hall_up => []} end, name: __MODULE__)
  end

  def new(button_type, floor) when is_integer(floor) and button_type in @valid_order do
    Agent.update(__MODULE__,
    fn map -> Map.update(map, button_type, [], fn list -> Enum.uniq([floor | list]) end) end)
  end

  def delete(button_type, floor) when is_integer(floor) and button_type in @valid_order do
    Agent.update(__MODULE__, fn map -> Map.update(map, button_type, [], fn list -> List.delete(list, floor) end) end)
  end

  def choose_direction(%Elevator{} = e) do
    case e.direction do
      :up ->
        cond do
          orders_above?(e.floor) -> :up
          orders_below?(e.floor) -> :down
          true -> :stop
        end

      _->
        cond do
          orders_below?(e.floor) -> :down
          orders_above?(e.floor) -> :up
          true -> :stop
        end
    end
  end

  def should_stop?(%Elevator{} = e) do
    case e.direction do
      :up ->
        e.floor in Map.get(order_map(), :cab) or
        e.floor in Map.get(order_map(), :hall_up) or
        !orders_above?(e.floor)
      :down ->
        e.floor in Map.get(order_map(), :cab) or
        e.floor in Map.get(order_map(), :hall_down) or
        !orders_below?(e.floor)
      _->
        true
    end
  end

  def clear_at_floor(floor) do
    order_map()
    |> Map.keys()
    |> Enum.each(fn button_type -> delete(button_type, floor) end)
  end

  # Private helper functions
  def order_map do
    Agent.get(__MODULE__, fn orders -> orders end)
  end

  def orders_above?(floor) do
    order_map()
    |> Map.values()
    |> List.flatten()
    |> Enum.filter(fn v -> v > floor end)
    |> Enum.any?
  end

  def orders_below?(floor) do
    order_map()
    |> Map.values()
    |> List.flatten()
    |> Enum.filter(fn v -> v < floor end)
    |> Enum.any?
  end

end
