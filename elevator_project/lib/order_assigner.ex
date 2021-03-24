defmodule OrderAssigner do
  use GenServer
  @name :order_assigner

  def start_link do
    GenServer.start_link(__MODULE__, [], name: @name)
  end
  # API ------------------------------------------------
  def new_order(%Order{} = order) do
    case Map.get(order, :button_type) do
      :cab -> GenServer.cast(__MODULE__, {:new_cab_order, order})
      _    -> GenServer.cast(__MODULE__, {:new_hall_order, order})
    end
  end

  # Casts -----------------------------------------------new_hall_order
  def handle_cast({:new_hall_order, %Order{} = order}, _state) do
    all_nodes = [Node.self() | Node.list()]
    IO.puts("HALL")
    ##ask for other nodes cost
    GenServer.multi_call(all_nodes, @name, )
    ##Choose elevator, send to OrderDistributor
    {:noreply, _state}
  end

  def handle_cast({:new_cab_order, %Order{} = order}, _state) do
    IO.puts("CAB")
    #Samkjør med OrderDistributor
    #OrderDistributor.handle_order()
    {:noreply, _state}
  end

  # Calls -----------------------------------------------
  def handle_call({:get_cost, %Order{} = order}, _state) do
    ##calculate cost
    cost = OrderAssigner.CostCalculation.cost(order)
    {:reply, {%Order{} = order, cost}, _state}
  end

  # Helper functions ------------------------------------
end

defmodule OrderAssigner.CostCalculation do
  def cost(%Order{} = order) do
    ## Implement cost function
    ## get order map from elevator_operator
    Elevator.get_orders();
    cost = 1;
  end
end
