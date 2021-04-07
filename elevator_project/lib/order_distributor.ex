defmodule OrderDistributor do
  use GenServer

  @name :order_distributor
  @broadcast_timeout 100

  def start_link do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  # API ------------------------------------------------
  def distribute_order(%Order{} = order, node) do
    GenServer.cast({@name, node}, {:new_order, order})
  end

  def delete_order(order, node) do
    GenServer.call({@name, node}, {:delete_order, order})
  end

  # Init -----------------------------------------------
  @impl true
  def init(_init_arg) do
    {:ok, []}
  end

  # Casts -----------------------------------------------
  @impl true
  def handle_cast({:new_order, order}, state) do
    backup_new_order(order)
    Elevator.Orders.new(order.button_type, order.floor)
    #turn on lights
    {:noreply, state}
  end

  # Calls -----------------------------------------------
  @impl true
  def handle_call(:request_backup, _from, state) do
    {:reply, OrderBackup.get(), state}
  end

  @impl true
  def handle_call({:new_backup, backup}, _from, state) do
    OrderBackup.merge([backup ++ OrderBackup.get()])
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete_order, order}, _from, state) do
    Elevator.Orders.delete(order.button_type, order.floor)
    {:reply, :ok, state}
  end

  # Helper functions ------------------------------------
  defp backup_new_order(%Order{} = order) do

    {_replies, _bad_nodes} = GenServer.multi_call(
      [Node.self | Node.list()],
      :order_backup,
      {:backup_new_order, order},
      @broadcast_timeout
    )
    #check for packet loss on bad nodes
  end

  defp request_order_backup() do
    {replies, _bad_nodes} = GenServer.multi_call(
      [Node.self() | Node.list()],
      :elevator_orders,
      {:request_backup},
      @broadcast_timeout
    )
    current_backup = OrderBackup.get()
    OrderBackup.merge(current_backup ++ replies)
  end
end
