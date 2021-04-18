defmodule Order do
  @valid_orders [:cab, :hall_down, :hall_up]
  @enforce_keys [:button_type, :floor]
  defstruct [:button_type, :floor, :owner]

  def new(button_type, floor) when button_type in @valid_orders and is_integer(floor) do
    %Order{
      button_type: button_type,
      floor: floor,
      owner: nil
    }
  end
end


defmodule Orders do
  use Agent

  def start_link(_init_arg) do
    Agent.start_link(fn -> MapSet.new() end, name: __MODULE__)
  end

  # API -----------------------------------------------
  def new(%Order{} = order) do
    Agent.update(__MODULE__, fn orders -> MapSet.put(orders, order) end)
  end

  def delete(%Order{} = order) do
    Agent.update(__MODULE__, fn orders -> remove(orders, order) end)
  end

  def get() do
    Agent.get(__MODULE__, fn orders -> orders end)
  end

  def set(orders) do
    Agent.cast(__MODULE__, fn _old_orders -> orders end)
  end

  # Helper functions ----------------------------------
  defp remove(orders, %Order{button_type: :cab} = order) do
    MapSet.delete(orders, order)
  end

  defp remove(orders, %Order{button_type: _hall} = order) do
    orders
    |> Enum.filter(fn %Order{} = o -> {o.button_type, o.floor} != {order.button_type, order.floor} end)
    |> MapSet.new()
  end
end
