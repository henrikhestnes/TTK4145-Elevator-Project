defmodule OrderAssigner do
  use GenServer
  alias OrderAssigner.CostCalculation
  @name :order_assigner
  @auction_timeout 100

  def start_link do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  # API ------------------------------------------------
  def assign_order(%Order{} = order) do
    case order.button_type do
      :cab    -> GenServer.cast(@name, {:new_cab_order,  order})
      _hall   -> GenServer.cast(@name, {:new_hall_order, order})
      end
  end

  # Init ------------------------------------------------
  @impl true
  def init(_init_arg) do
    {:ok, []}
  end

  # Casts -----------------------------------------------
  @impl true
  def handle_cast({:new_hall_order, %Order{} = order}, state) do
    own_cost = {Node.self(), CostCalculation.cost(order)}
    {others_costs, _bad_nodes} = GenServer.multi_call(
      Node.list(),
      @name,
      {:get_cost, order},
      @auction_timeout
    )

    all_costs = [own_cost | others_costs]
    {best_elevator, _cost} =
      all_costs
      |> List.keysort(1)
      |> List.first()

    IO.puts(best_elevator)
    OrderDistributor.distribute_order(order, best_elevator)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:new_cab_order, %Order{} = order}, state) do
    OrderDistributor.distribute_order(order, Node.self())
    {:noreply, state}
  end

  # Calls -----------------------------------------------
  @impl true
  def handle_call({:get_cost, %Order{} = order}, _from, state) do
    cost = CostCalculation.cost(order)
    {:reply, cost, state}
  end

  # Helper functions ------------------------------------
end

defmodule OrderAssigner.CostCalculation do

  def cost(%Order{} = order) do
    #cost only based on length of order map
    # Elevator.Orders.get()
    # |> Map.values()
    # |> List.flatten()
    # |> length()

    {floor, direction, state, orders} = Elevator.get_data()
    number_of_orders = orders |> Map.values() |> List.flatten() |> length()
    initial_cost = number_of_orders + abs(order.floor - floor)

    cond do
      state == :idle ->
        cost = initial_cost

      state ==
      order.button_type == :hall_up and direction == :down

    end
  end
end
