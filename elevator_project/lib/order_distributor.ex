defmodule OrderDistributor do
  use GenServer

  @broadcast_timeout 2000

  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  def add_order(order) do
    GenServer.call(__MODULE__, {:add_order, order})
  end

  def delete_order(order = %Order{}) do
    
  end

  def broadcast_backup(order = %Order{}) do
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

  def handle_call({:new_order, order, node}) do
    this_node = Node.self()
    case node do
      this_node-> 
        add_order(order)
        broadcast_backup(order)
      other->
        broadcast_backup(order)
    end
    {:reply, :ok, }
  end

  def handle_call(:broadcast_backup) do
    OrderBackup.merge()
  end

end