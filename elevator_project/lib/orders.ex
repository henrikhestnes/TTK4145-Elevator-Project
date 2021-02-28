defmodule Orders do
  use Agent

  @valid_order [:hall_down, :cab, :hall_up]

  def start_link() do
    init_map = %{:cab => [], :hall}
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def set_order(order) do
    Agent.update(__MODULE__, fn map -> Map.put(map, order, :true) end)
  end

  def clear_order(order) do
    Agent.update(__MODULE__, fn map -> Map.delete(map, order) end)
  end

  def get_orders do
    Agent.get(__MODULE__, fn orders -> orders end)
  end
end
