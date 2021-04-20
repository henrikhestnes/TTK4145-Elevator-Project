defmodule Order do
  @moduledoc """
  Defines the order struct.
  """

  @valid_orders [:cab, :hall_down, :hall_up]

  @enforce_keys [:button_type, :floor]
  defstruct [:button_type, :floor, :owner]

  @doc """
  Creates an order with given button_type and floor. The owner is set to `nil`.
  ## Parameters
    - button_type: Button type of the order. Can be :cab, :hall_up or :hall_down :: atom()
    - floor: Floor of the order :: integer()
  ## Return
    - The created order :: %Order{}
  """
  def new(button_type, floor) when button_type in @valid_orders and is_integer(floor) do
    %Order{
      button_type: button_type,
      floor: floor,
      owner: nil
    }
  end
end

defmodule Orders do
  @moduledoc """
  Maintains a set of uniqe orders. Orders with equal button type and floor but different
  owners are counted as different orders, to be able to keep track of the cab calls of
  multiple elevators.

  Uses the following modules:
    - Order
  """
  
  use Agent

  @doc false
  def start_link(_init_arg) do
    Agent.start_link(fn -> MapSet.new() end, name: __MODULE__)
  end

  # API -------------------------------------------------
  @doc """
  Adds an order to the set.
  ## Parameters
    - order: Order to be added :: %Order{}

  ## Return
    - :ok :: atom()
  """
  def new(%Order{} = order) do
    Agent.update(__MODULE__, fn orders -> MapSet.put(orders, order) end)
  end

  @doc """
  Deletes an order from the set. If the order to be deleted is a hall call,
  all orders with the given button type and floor are deleted from the set.
  ## Parameters
    - order: Order to be deleted :: %Order{}

  ## Return
    - :ok :: atom()
  """
  def delete(%Order{} = order) do
    Agent.update(__MODULE__, fn orders -> remove(orders, order) end)
  end

  @doc """
  Retrieves the set of orders.
  ## Return
    - The current order set :: %MapSet
  """
  def get() do
    Agent.get(__MODULE__, fn orders -> orders end)
  end

  @doc """
  Sets the order set.
  ## Parameters
    - orders: New value of the order set :: %Order{}

  ## Return
    - :ok :: atom()
  """
  def set(orders) do
    Agent.cast(__MODULE__, fn _old_orders -> orders end)
  end

  # Helper functions ------------------------------------
  defp remove(orders, %Order{button_type: :cab} = order) do
    MapSet.delete(orders, order)
  end

  defp remove(orders, %Order{button_type: _hall} = order) do
    orders
    |> Enum.filter(fn %Order{} = o ->
      {o.button_type, o.floor} != {order.button_type, order.floor}
    end)
    |> MapSet.new()
  end
end
