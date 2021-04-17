defmodule OrderDistributor do
  @moduledoc """
  Distributing orders to the best suited elevator.
  Tells `OrderBackup` to add order, `Watchdog` to start watchdog timer,
  `ElevatorOperator` to take the order if it is assigned and `Driver` to set lights.

  Uses the following modules:
  - `OrderBackup`
  - `Watchdog`
  - `ElevatorOperator`
  - `Driver`
  - `Order`
  """
  use GenServer

  @name :order_distributor
  @call_timeout 1_000

  def start_link(_init_arg) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  # API ------------------------------------------------
  @doc """
  Distributes given order to best suited elevator, and tells the other elevators
  that a order is distributed to a given elevator.

  ## Parameters
    - order: Order struct on the form defined in module `Order`
    - best_elevator: Which elevator serving the order

  ## Return
    - :ok
  """
  def distribute_new(%Order{} = order, best_elevator) do
    GenServer.multi_call(
      Node.list(),
      @name,
      {:new_order, order, best_elevator},
      @call_timeout
    )
    GenServer.call(@name, {:new_order, order, best_elevator}, @call_timeout)
  end

  @doc """
  Tells all elevator that given order(s) is completed

  ## Parameters
    - order: Order struct on the form defined in module `Order`

  ## Return
    - :ok
  """
  def distribute_completed(%Order{} = order) do
    GenServer.multi_call(
      Node.list(),
      @name,
      {:delete_order, order, Node.self()},
      @call_timeout
    )
    GenServer.call(@name, {:delete_order, order, Node.self()}, @call_timeout)
  end

  def distribute_completed(orders) when is_list(orders) do
    Enum.each(orders, fn %Order{} = order -> distribute_completed(order) end)
  end

  @doc """
  Requests backups for all other elevators, and merges these
  backups together with its own.

  ## Return
    - :ok
  """
  def request_backup() do
    {others_backups, _bad_nodes} = GenServer.multi_call(
      Node.list(),
      @name,
      :get_backup,
      @call_timeout
    )

    own_backup = {Node.self(), OrderBackup.get()}
    [own_backup | others_backups]
    |> Enum.map(fn {_node, backup} -> backup end)
    |> OrderBackup.merge()

    merged_backup = OrderBackup.get()
    if own_cab_calls = merged_backup.cab_calls[Node.self()] do
      Enum.each(
        own_cab_calls,
        fn %Order{} = order -> ElevatorOperator.order_button_press(order) end
      )

      Enum.each(
        own_cab_calls,
        fn %Order{} = order -> Driver.set_order_button_light(order.button_type, order.floor, :on) end
      )
    end
  end

  # Init -----------------------------------------------
  @impl true
  def init(_init_arg) do
    {:ok, []}
  end

  # Calls -----------------------------------------------
  @impl true
  def handle_call({:new_order, %Order{button_type: :cab} = order, best_elevator}, _from, state) do
    OrderBackup.new(order, best_elevator)
    if best_elevator == Node.self() do
      ElevatorOperator.order_button_press(order)
      Driver.set_order_button_light(order.button_type, order.floor, :on)
    end
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:new_order, %Order{button_type: _hall} = order, best_elevator}, _from, state) do
    OrderBackup.new(order, best_elevator)
    if best_elevator == Node.self() do
      ElevatorOperator.order_button_press(order)
    end
    Watchdog.start(order, best_elevator)
    Driver.set_order_button_light(order.button_type, order.floor, :on)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete_order, %Order{button_type: :cab} = order, node}, _from, state) do
    OrderBackup.delete(order, node)
    if node == Node.self() do
      Driver.set_order_button_light(order.button_type, order.floor, :off)
    end
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete_order, %Order{button_type: _hall} = order, node}, _from, state) do
    IO.inspect(order, label: "completed order")
    OrderBackup.delete(order, node)
    Watchdog.stop(order)
    Driver.set_order_button_light(order.button_type, order.floor, :off)
    ElevatorOperator.Orders.delete(order.button_type, order.floor)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_backup, _from, state) do
    {:reply, OrderBackup.get(), state}
  end
end
