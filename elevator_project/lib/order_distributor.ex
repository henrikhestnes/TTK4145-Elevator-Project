defmodule OrderDistributor do
  use GenServer

  @broadcast_timeout 2000

  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def add_order(order = %Order{}, node) do
    GenServer.call(node, {:add_order, order})

  end

  def delete_order(%Order{}, node) do
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
    {replies, bad_nodes} = GenServer.multi_call(
      [Node.self() | Node.list()],
      :Orders,
      {:request_backup},
      @broadcast_timeout
    )

    # Todo: Finne en korrekt backup
  end

  def handle_cast({:request_backup}, _from, state) do
    Genserver.cast(__MODULE__, {:send_backup, from})
  end

  def handle_call({:add_order, order}, _from, state) do
    Orders.new(order.button_type, order.floor)
    {:reply, state}
  end

  def handle_call({:delete_order, order}) do

  end

end
