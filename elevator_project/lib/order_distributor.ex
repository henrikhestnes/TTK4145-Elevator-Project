
defmodule OrderDistributor do
  use GenServer

  @name :order_distributor
  @call_timeout 1_000

  def start_link(_init_arg) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  # API ------------------------------------------------
  def distribute_new(%Order{} = order) do
    GenServer.multi_call(@name, {:new_order, order})
    end

  def distribute_completed(%Order{} = order) do
    GenServer.multi_call(@name, {:delete_order, order})
  end

  def distribute_completed(orders) when is_list(orders) do
    Enum.each(orders, fn %Order{} = order -> distribute_completed(order) end)
  end

  def request_backup() do
    backup = union(all_orders())

    own_cab_calls = Enum.filter(
      backup,
      fn %Order{} = order -> order.button_type == :cab and order.owner == Node.self() end
    )
    if not Enum.empty?(own_cab_calls) do
      Enum.each(
        own_cab_calls,
        fn %Order{} = order -> ElevatorOperator.order_button_press(order) end
      )

      Enum.each(
        own_cab_calls,
        fn %Order{} = order -> Driver.set_order_button_light(order.button_type, order.floor, :on) end
      )
    end

    set_orders(backup)
  end

  def get_orders() do
    GenServer.call(@name, :get_orders)
  end

  # Init ------------------------------------------------
  @impl true
  def init(_init_arg) do
    {:ok, MapSet.new()}
  end

  # Calls -----------------------------------------------
  @impl true
  def handle_call({:new_order, %Order{button_type: :cab} = order}, _from, orders) do
    if order.owner == Node.self() do
      ElevatorOperator.order_button_press(order)
      Driver.set_order_button_light(order.button_type, order.floor, :on)
    end
    {:reply, :ok, MapSet.put(orders, order)}
  end

  @impl true
  def handle_call({:new_order, %Order{button_type: _hall} = order}, _from, orders) do
    if order.owner == Node.self() do
      ElevatorOperator.order_button_press(order)
    end
    Watchdog.start(order)
    Driver.set_order_button_light(order.button_type, order.floor, :on)
    {:reply, :ok, MapSet.put(orders, order)}
  end

  @impl true
  def handle_call({:delete_order, %Order{button_type: :cab} = order}, _from, orders) do
    if order.owner == Node.self() do
      Driver.set_order_button_light(order.button_type, order.floor, :off)
    end
    {:reply, :ok, MapSet.delete(orders, order)}
  end

  @impl true
  def handle_call({:delete_order, %Order{button_type: _hall} = order}, _from, orders) do
    Watchdog.stop(order)
    Driver.set_order_button_light(order.button_type, order.floor, :off)
    {:reply, :ok, MapSet.delete(orders, order)}
  end

  @impl true
  def handle_call(:get_orders, _from, orders) do
    {:reply, orders, orders}
  end

  @impl true
  def handle_cast({:set_orders, orders}, _orders) do
    {:noreply, orders}
  end

  # Helper functions ------------------------------------
  def set_orders(orders) do
    GenServer.cast(@name, {:set_orders, orders})
  end

  def all_orders() do
    {orders, _bad_nodes} = GenServer.multi_call(@name, :get_orders)
    orders
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
end
