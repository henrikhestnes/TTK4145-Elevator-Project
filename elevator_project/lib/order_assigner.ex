defmodule OrderAssigner do
  use GenServer
  @name :order_assigner

  def start_link do
    GenServer.start_link(__MODULE__, [], name: @name)
  end
  # API ------------------------------------------------
  def new_order(%Order{} = order) do
    case order.button_type do
      :cab -> GenServer.cast(@name, {:new_cab_order,  %Order{} = order})
      _    -> GenServer.cast(@name, {:new_hall_order, %Order{} = order})
      end
  end

  # Init ------------------------------------------------
  # def init({init_arg}) do
  #   {:ok, init_arg}
  # end

  # Casts -----------------------------------------------
  @impl true
  def handle_cast({:new_hall_order, %Order{} = order}, _state) do
    all_nodes = [Node.self() | Node.list()]
    {replies, _bad_nodes} = GenServer.multi_call(all_nodes, @name, {:get_cost, order})
    best_elevator = replies |> List.keysort(1)
                            |> List.first()
                            |> elem(0)
    OrderDistributor.handle_order(order, best_elevator)
    {:noreply}
  end

  @impl true
  def handle_cast({:new_cab_order, %Order{} = order}, _state) do
    OrderDistributor.handle_order(order, Node.self())
    {:noreply}
  end

  # Calls -----------------------------------------------
  def handle_call({:get_cost, %Order{} = order}, _state) do
    ##calculate cost
    cost = OrderAssigner.CostCalculation.cost(order)
    {:reply, {order, cost}}
  end

  # Helper functions ------------------------------------
end

defmodule OrderAssigner.CostCalculation do
  def cost(%Order{} = order) do
    ## Implement cost function
    ## get order map from elevator_operator
    orders = Elevator.get_orders();
    #cost = 1;
  end
end
