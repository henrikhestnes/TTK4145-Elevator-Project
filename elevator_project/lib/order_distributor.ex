# defmodule OrderDistributor do
#   use GenServer

#   @name :order_distributor
#   @broadcast_timeout 100

#   def start_link do
#     GenServer.start_link(__MODULE__, [], name: @name)
#   end

#   # API ------------------------------------------------
#   def distribute_order(%Order{} = order, node) do
#     GenServer.cast({@name, node}, {:new_order, order})
#   end

#   def delete_order(order, node) do
#     GenServer.call({@name, node}, {:delete_order, order})
#   end

#   def delete_orders(orders) do
#     Enum.each(orders, fn order -> delete_order(order, Node.self()) end)
#   end

#   # Init -----------------------------------------------
#   @impl true
#   def init(_init_arg) do
#     {:ok, []}
#   end

#   # Casts -----------------------------------------------
#   @impl true
#   def handle_cast({:new_order, order}, state) do
#     backup_new_order(order)
#     Elevator.request_button_press(order.button_type, order.floor)
#     # Turn on order lights
#     {:noreply, state}
#   end

#   # Calls -----------------------------------------------
#   @impl true
#   def handle_call(:request_backup, _from, state) do
#     {:reply, OrderBackup.get(), state}
#   end

#   @impl true
#   def handle_call({:new_backup, backup}, _from, state) do
#     OrderBackup.merge([backup ++ OrderBackup.get()])
#     {:reply, :ok, state}
#   end

#   @impl true
#   def handle_call({:delete_order, order}, _from, state) do
#     # Delete from backup
#     # Turn off order lights
#     {:reply, :ok, state}
#   end

#   # Helper functions ------------------------------------
#   defp backup_new_order(%Order{} = order) do

#     {_replies, _bad_nodes} = GenServer.multi_call(
#       [Node.self | Node.list()],
#       :order_backup,
#       {:backup_new_order, order},
#       @broadcast_timeout
#     )
#     #check for packet loss on bad nodes
#   end

#   defp request_order_backup() do
#     {replies, _bad_nodes} = GenServer.multi_call(
#       [Node.self() | Node.list()],
#       :elevator_orders,
#       {:request_backup},
#       @broadcast_timeout
#     )
#     current_backup = OrderBackup.get()
#     OrderBackup.merge(current_backup ++ replies)
#   end
# end


defmodule OrderDistributor do
  use GenServer

  @name :order_distributor
  @broadcast_timeout 100

  def start_link do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  # API ------------------------------------------------
  def distribute_new(%Order{} = order, best_elevator) do
    GenServer.call(__MODULE__, {:new_order, order, best_elevator}, @broadcast_timeout)
    {replies, bad_nodes} = GenServer.multi_call(
      Node.list(),
      @name,
      {:new_order, order, best_elevator},
      @broadcast_timeout
    )
    # Check for packet loss on bad nodes
  end

  def distribute_completed(%Order{} = order) do
    GenServer.call(__MODULE__, {:delete_order, order, Node.self()}, @broadcast_timeout)
    {replies, bad_nodes} = GenServer.multi_call(
      Node.list(),
      @name,
      {:delete_order, order, Node.self()},
      @broadcast_timeout
    )
    # Check for packet loss on bad nodes
  end

  def distribute_completed(orders) when is_list(orders) do
    Enum.each(orders, fn %Order{} = order -> distribute_completed(order) end)
  end

  def request_backup() do
    {others_backups, bad_nodes} = GenServer.multi_call(
      Node.list(),
      @name,
      :get_backup,
      @broadcast_timeout
    )
    #check for packet loss on bad nodes

    own_backup = {Node.self(), OrderBackup.get()}
    [own_backup | others_backups]
    |> Enum.map(fn {_node, backup} -> backup end)
    |> OrderBackup.merge()

    merged_backup = OrderBackup.get()
    if own_cab_calls = merged_backup.cab_calls[Node.self()] do
      Enum.each(
        own_cab_calls,
        fn %Order{} = order -> Elevator.request_button_press(order.button_type, order.floor) end
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
      Elevator.request_button_press(order.button_type, order.floor)
      Driver.set_order_button_light(order.button_type, order.floor, :on)
    end
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:new_order, %Order{button_type: _hall} = order, best_elevator}, _from, state) do
    OrderBackup.new(order, best_elevator)
    if best_elevator == Node.self() do
      Elevator.request_button_press(order.button_type, order.floor)
    end
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
    Driver.set_order_button_light(order.button_type, order.floor, :off)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_backup, _from, state) do
    {:reply, OrderBackup.get(), state}
  end

  # Helper functions ------------------------------------
end
