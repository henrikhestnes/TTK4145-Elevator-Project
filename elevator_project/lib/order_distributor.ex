defmodule OrderDistributor do
  use GenServer

  @broadcast_timeout 2000

  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  def add_order(order = %Order{}, node) do
    GenServer.call(node, {:add_order, order}) 
    
  end

  def delete_order(order = %Order{}, node) do
    GenServer.call(node, {:delete_order, order})   
  end

  def broadcast(order = %Order{}) do
    GenServer.multi_call(
      [Node.self() | Node.list()],
      :Orders,
      {:new_order, order},
      @broadcast_timeout
    )
  end

  def request_order_backup() do
    {backups, _bad_nodes} = GenServer.multi_call(
      [Node.self() | Node.list()],
      :Orders,
      {:request_backup},
      @broadcast_timeout
    )

    _backup = Utilities.compare_backups(backups)
    # Todo: update backup server
  end

  def handle_cast({:request_backup}, _from, state) do
    request_order_backup()
  end 

  def handle_call({:add_order, order}, _from, state) do
    Orders.new(order.button_type, order.floor)
    {:reply, state}
  end

  def handle_call({:delete_order, order}) do
    
  end


defp compare_backups(old_backup, backups) do
  [next_backup | remaining_backups] = backups
  case remaining_backups do
    [] -> 
      Enum.filter(next_backup, fn el -> !Enum.member?(old_backup, el) end) ++ old_backup
    remaining_backups -> 
      new_backup = Enum.filter(next_backup, fn el -> !Enum.member?(old_backup, el) end) ++ old_backup
      IO.puts(old_backup)
      compare_backups(new_backup, remaining_backups)
  end
end

def compare_backups(backups) do
  [first_backup | remaining_backups] = backups
  compare_backups(first_backup, remaining_backups)
end
end