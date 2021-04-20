defmodule Order do
  @moduledoc """
  Module defining the form of the order struct, as well as creating orders on the right form.
  The order struct contains information of :button_type and _floor.
  """

  @valid_orders [:cab, :hall_down, :hall_up]

  @enforce_keys [:button_type, :floor]
  defstruct [:button_type, :floor, :owner]

  @doc """
  Creates an order struct for an order based on button_type and floor
  ## Parameters
    - button_type: Button of type :cab, :hall_up or :hall_down :: atom()
    - floor: Floor of the order :: integer()
  ## Return
    - Creates an order :: %Order{}
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
  Module defining how to keep track of the current orders.
  Uses the following modules:
    - Order
  """
  use Agent

  def start_link(_init_arg) do
    Agent.start_link(fn -> MapSet.new() end, name: __MODULE__)
  end

  # API -------------------------------------------------
  @doc """
  Adds an order to the map.
  ## Parameters
    - order: Order struct on the form defined in module `Order` :: %Order{}
  ## Return
    - :ok :: atom()
  """
  def new(%Order{} = order) do
    Agent.update(__MODULE__, fn orders -> MapSet.put(orders, order) end)
  end

  @doc """
  Deletes an order in the map.
  ## Parameters
    - order: Order struct on the form defined in module `Order` :: %Order{}
  ## Return
    - :ok :: atom()
  """
  def delete(%Order{} = order) do
    Agent.update(__MODULE__, fn orders -> remove(orders, order) end)
  end

  def get() do
    Agent.get(__MODULE__, fn orders -> orders end)
  end

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
