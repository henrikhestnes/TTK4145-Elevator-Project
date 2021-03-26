defmodule OrderAssigner do
  use GenServer
  @name :order_assigner
  @auction_timeout 1_000

  def start_link do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  #example_order = %Order{button_type: :hall_up, floor: 1, watchdog_ref: nil}

  # API ------------------------------------------------
  def new_order(%Order{} = order) do
    case order.button_type do
      :cab    -> GenServer.cast(@name, {:new_cab_order,  order})
      _hall   -> GenServer.cast(@name, {:new_hall_order, order})
      end
  end

  # Init ------------------------------------------------
  # @impl true
  # def init(init_arg) do
  #   {:ok, init_arg}
  # end

  # Casts -----------------------------------------------
  @impl true
  def handle_cast({:new_hall_order, %Order{} = order}, state) do
    #IO.puts("hello")
    all_nodes = [Node.self() | Node.list()]
    #{replies, _bad_nodes} = GenServer.multi_call(all_nodes, @name, {:get_cost, order}, @auction_timeout)
    #best_elevator = replies |> List.keysort(1) |> List.first() |> elem(0)
    IO.puts("helo")
    #OrderDistributor.handle_order(order, best_elevator)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:new_cab_order, %Order{} = order}, state) do
    #OrderDistributor.handle_order(order, Node.self())
    IO.puts("yessir")
    {:noreply, state}
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
