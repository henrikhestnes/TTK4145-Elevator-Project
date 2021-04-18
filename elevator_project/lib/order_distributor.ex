defmodule OrderDistributor do
  use GenServer

  @name :order_distributor
  @call_timeout 5_000

  def start_link(_init_arg) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  # API ------------------------------------------------
  def distribute_new(%Order{} = order) do
    GenServer.multi_call(
      [Node.self() | Node.list()],
      @name,
      {:new_order, order},
      @call_timeout
    )
  end

  def distribute_completed(%Order{} = order) do
    GenServer.multi_call(
      [Node.self() | Node.list()],
      @name,
      {:delete_order, order},
      @call_timeout
    )
  end

  def distribute_completed(orders) when is_list(orders) do
    Enum.each(orders, fn %Order{} = order -> distribute_completed(order) end)
  end

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

  # Calls -----------------------------------------------
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
        @name,
        :get_orders,
        @call_timeout
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
