defmodule OrderDistributor do
  @moduledoc """
  Distributes assigned and completed orders to all elevators in the node cluster.
  Can also request backup from other elevators in the node cluster, and update
  `Orders` accordingly. Upon reception of assigned orders the orders are added to `Orders`,
  `ElevatorOperator` is singalled to take the orders if it is the assigned elevator,
  watchdog timers are started for hall calls, and order button lights are set.
  Upon reception of completed orders the orders are removed from `Orders`,
  watchdog timers are stopped for hall calls, and order button lights are cleared.


  Uses the following modules:
  - `Order`
  - `Orders`
  - `Watchdog`
  - `ElevatorOperator`
  - `Driver`
  """
  use GenServer

  @distribution_call_timeout 10_000
  @backup_call_timeout 5_000

  def start_link(_init_arg) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  # API ------------------------------------------------
  @doc """
  Distributes a given order to all elevators in the node cluster. Spawning a multi_call
  effectively becomes a multi_cast with an acknowledgement and a given timeout.
  ## Parameters
    - order: Order to be distributed as new :: %Order{}
    - best_elevator: Elevator to serve the order :: atom()

  ## Return
    - :ok :: atom()
  """
  def distribute_new(%Order{} = order) do
    spawn(fn ->
      GenServer.multi_call(
        [Node.self() | Node.list()],
        __MODULE__,
        {:new_order, order},
        @distribution_call_timeout
      )
      end
    )
  end

  @doc """
  Signals to all elevators in the node cluster that the given order has been completed.
  Spawning a multi_call effectively becomes a multi_cast with acknowledge and a given timeout.
  ## Parameters
    - order: Order to be distributed as completed :: %Order{}
    
  ## Return
    - :ok :: atom()
  """
  def distribute_completed(%Order{} = order) do
    spawn(fn ->
    GenServer.multi_call(
        [Node.self() | Node.list()],
        __MODULE__,
        {:delete_order, order},
        @distribution_call_timeout
      )
      end
    )
  end

  def distribute_completed(orders) when is_list(orders) do
    Enum.each(orders, fn %Order{} = order -> distribute_completed(order) end)
  end

  @doc """
  Requests backups for all other elevators in the node cluster, and merges these
  backups together with its own. All orders for which the elevator is assigned are
  signalled to `ElevatorOperator`, watchdog timers are started for hall calls,
  and order button lights are set for all orders in the merged backup.
  ## Return
    - :ok :: atom()
  """
  def request_backup() do
    backup = union(all_orders())
    Enum.each(backup, fn %Order{} = order -> inject_order(order) end)
    Orders.set(backup)
  end

  # Init ------------------------------------------------
  @impl true
  def init(_init_arg) do
    {:ok, []}
  end

  # Callbacks -------------------------------------------
  @impl true
  def handle_call({:new_order, %Order{button_type: :cab} = order}, _from, state) do
    Orders.new(order)

    if order.owner == Node.self() do
      ElevatorOperator.order_button_press(order)
      Driver.set_order_button_light(order.button_type, order.floor, :on)
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:new_order, %Order{button_type: _hall} = order}, _from, state) do
    Orders.new(order)

    if order.owner == Node.self() do
      ElevatorOperator.order_button_press(order)
    end

    Watchdog.start(order)
    Driver.set_order_button_light(order.button_type, order.floor, :on)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete_order, %Order{button_type: :cab} = order}, _from, state) do
    Orders.delete(order)

    if order.owner == Node.self() do
      Driver.set_order_button_light(order.button_type, order.floor, :off)
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete_order, %Order{button_type: _hall} = order}, _from, state) do
    Orders.delete(order)
    Watchdog.stop(order)
    Driver.set_order_button_light(order.button_type, order.floor, :off)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_orders, _from, state) do
    {:reply, Orders.get(), state}
  end

  # Helper functions ------------------------------------
  defp all_orders() do
    {all_orders, _bad_nodes} =
      GenServer.multi_call(
        [Node.self() | Node.list()],
        __MODULE__,
        :get_orders,
        @backup_call_timeout
      )

    Enum.map(all_orders, fn {_node, orders} -> orders end)
  end

  defp union(orders) do
    number_of_backups = length(orders)
    union(orders, number_of_backups, MapSet.new())
  end

  defp union(orders, number_of_backups, current_union, index \\ 0) do
    if index < number_of_backups do
      new_union = MapSet.union(current_union, Enum.at(orders, index))
      union(orders, number_of_backups, new_union, index + 1)
    else
      current_union
    end
  end

  defp inject_order(%Order{} = order) do
    if order.owner == Node.self() do
      Driver.set_order_button_light(order.button_type, order.floor, :on)
      ElevatorOperator.order_button_press(order)
    end

    if order.button_type != :cab do
      Driver.set_order_button_light(order.button_type, order.floor, :on)
      Watchdog.start(order)
    end
  end
end
