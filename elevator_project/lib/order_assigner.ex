defmodule OrderAssigner do
  use GenServer
  alias OrderAssigner.CostCalculation
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
  def init(_init_arg) do
    {:ok, []}
  end

  # Casts -----------------------------------------------
  @impl true
  def handle_cast({:new_hall_order, %Order{} = order}, state) do
    all_nodes = [self() | Node.list]
    {replies, _bad_nodes} = GenServer.multi_call(all_nodes, @name, {:get_cost, order}, @auction_timeout)
    best_elevator =
    if Enum.any?(replies) do
      replies |> List.keysort(1) |> List.first() |> elem(0)
    else
      :no_response
    end
    IO.puts(best_elevator)
    #OrderDistributor.handle_order(order, best_elevator)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:new_cab_order, %Order{} = _order}, state) do
    #OrderDistributor.handle_order(order, Node.self())
    {:noreply, state}
  end

  # Calls -----------------------------------------------
  @impl true
  def handle_call({:get_cost, %Order{} = _order}, _from, state) do
    ##calculate cost
    IO.puts("Calculating cost")
    cost = CostCalculation.cost()
    {:reply, cost, state}
  end

  # Helper functions ------------------------------------
end

defmodule OrderAssigner.CostCalculation do
  def cost() do
    _num_orders =
      Elevator.Orders.get()
      |> Map.values()
      |> List.flatten()
      |> length()

  end
end
