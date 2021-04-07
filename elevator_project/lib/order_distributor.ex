defmodule OrderDistributor do
  use GenServer

  @broadcast_timeout 2000

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_init_arg) do
    {:ok, []}
  end

  def handle_order(order, node) do
    GenServer.call({__MODULE__, node}, {:add_order, order})
  end

  def delete_order(order, node) do
    GenServer.call({__MODULE__, node}, {:delete_order, order})
  end

  def broadcast_backup() do
    GenServer.multi_call(
      [Node.self() | Node.list()],
      :elevator_orders,
      {:new_backup, OrderBackup.get()},
      @broadcast_timeout
    )
  end

  def request_order_backup() do
    {replies, _bad_nodes} = GenServer.multi_call(
      [Node.self() | Node.list()],
      :elevator_orders,
      {:request_backup},
      @broadcast_timeout
    )

    current_backup = OrderBackup.get()
    OrderBackup.merge(current_backup ++ replies)
  end

  def handle_call(:request_backup, _from, state) do
    {:reply, OrderBackup.get(), state}
  end

  def handle_call({:add_order, order}, _from, state) do
    Elevator.Orders.new(order.button_type, order.floor)
    #OrderBackup.add_order(order)
    #broadcast_backup()
    {:reply, :ok, state}
  end

  def handle_call({:new_backup, backup}, _from, state) do
    OrderBackup.merge([backup ++ OrderBackup.get()])
    {:reply, :ok, state}
  end

  def handle_call({:delete_order, order}, _from, state) do
    Elevator.Orders.delete(order.button_type, order.floor)
    {:reply, :ok, state}
  end
end
