defmodule OrderDistributor do
  use GenServer

  @broadcast_timeout 2000

  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  def handle_order(order, node) do
    GenServer.call(__MODULE__, {:add_order, order})
  end

  def delete_order(order = %Order{}) do
    
  end

  def broadcast_backup() do
    GenServer.multi_call(
      [Node.list()],
      :OrderDistributor,
      {:broadcast_backup, OrderBackup.order_map()},
      @broadcast_timeout
    )
  end

  def broadcast_order_complete(order = %Order{}, node) do
    GenServer.multi_call(
      [Node.self() | Node.list()],
      :OrderDistributor,
      {:order_complete, order},
      @broadcast_timeout
    )  
  end

  def request_order_backup() do
    {backups, _bad_nodes} = GenServer.multi_call(
      [Node.self() | Node.list()],
      :OrderDistributor,
      {:request_backup},
      @broadcast_timeout
    )

    current_backup = OrderBackup.order_map()
    OrderBackup.merge(backups, current_backup)
  end

  def handle_call({:request_backup}, _from, _state) do
    {:reply, OrderBackup.order_map()}
  end 

  def handle_call({:order_complete, node}, _from, _state) do
    
  end

  def handle_call({:add_order, order, node}, _from, state) do
    this_node = Node.self()
    case node do
      this_node-> 
        Orders.new(order[:button_type], order[:floor])
        broadcast_backup()
      other->
        broadcast_backup()
    end
    {:reply, :ok, state}
  end

  def handle_call(:broadcast_backup, _from, state) do
    OrderBackup.merge()
    {:reply, {:received, Node.self()}, state}
  end
end