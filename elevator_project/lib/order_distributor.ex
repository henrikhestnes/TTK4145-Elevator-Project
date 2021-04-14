
defmodule OrderDistributor do
  use GenServer

  @name :order_distributor
  @call_timeout 10_000

  def start_link(_init_arg) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  # API ------------------------------------------------
  def distribute_new(%Order{} = order, best_elevator) do
    GenServer.multi_call(
      Node.list(),
      @name,
      {:new_order, order, best_elevator},
      @call_timeout
    )
    GenServer.call(@name, {:new_order, order, best_elevator}, @call_timeout)
    end

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

    Enum.each(
      merged_backup.hall_calls,
      fn %Order{} = order -> Driver.set_order_button_light(order.button_type, order.floor, :on) end
    )
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
    OrderBackup.delete(order, node)
    Watchdog.stop(order)
    Driver.set_order_button_light(order.button_type, order.floor, :off)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_backup, _from, state) do
    {:reply, OrderBackup.get(), state}
  end
end
