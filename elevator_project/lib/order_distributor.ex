defmodule OrderDistributor do
  use GenServer

  @broadcast_timeout 2000

  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  def add_order() do
    GenServer.call()
  end

  def delete_order(order = %Order{}, node) do
    GenServer.call(node, {:delete_order, order})   
  end

  def broadcast_backup(order = %Order{}, node) do
    GenServer.multi_call(
      [Node.self() | Node.list()],
      :OrderDistributor,
      {:broadcast_backup, OrderBackup.order_map(), node},
      @broadcast_timeout
    )
  end

  def broadcast_order_complete(order = %Order{}, node)

  def request_order_backup() do
    {backups, _bad_nodes} = GenServer.multi_call(
      [Node.self() | Node.list()],
      :OrderDistributor,
      {:request_backup},
      @broadcast_timeout
    )

    current_backup = OrderBackup.order_map()
    merge_backups(backups, current_backup)
  end

  def handle_call({:request_backup}, _from, state) do
    {:reply, OrderBackup.order_map()}
  end 

  def handle_call({:new_order, order, node}) do
    case node do
      Node.self() -> 
        Orders.new(order.)
        update_backup()
        broadcast_backup(order, node)
      other->
        broadcast_backup(order, node)
    end
    {:reply, :ok, }
  end

  def handle_call(:broadcast_backup) do
    merge_backups()
  end

