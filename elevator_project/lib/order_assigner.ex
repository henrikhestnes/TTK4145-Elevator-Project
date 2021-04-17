defmodule OrderAssigner do
  @moduledoc """
  Assigning orders to the best suited elevator.

  Uses the following modules:
  - `Order`
  - `OrderDistributor`
  - `ElevatorOperator`
  - `OrderAssigner.CostCalculation`
  """

  use GenServer
  alias OrderAssigner.CostCalculation

  @name :order_assigner
  @call_timeout 1_000

  def start_link(_init_arg) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  # API -------------------------------------------------
  @doc """
  Assigning order to the best suited elevator. If order gets redristibuted, the same
  elevator will not get the same order twice.

  ## Parameters
    - order: Order struct on the form defined in module `Order`
    - prev_assigned_node: Previously assigned elevator

  ## Return
    - :ok
  """
  def assign_order(%Order{} = order, prev_assigned_node \\ nil) do
    case order.button_type do
      :cab  -> GenServer.cast(@name, {:new_cab_order, order})
      _hall -> GenServer.cast(@name, {:new_hall_order, order, prev_assigned_node})
      end
  end

  # Init ------------------------------------------------
  @impl true
  def init(_init_arg) do
    {:ok, []}
  end

  # Casts -----------------------------------------------
  @impl true
  def handle_cast({:new_hall_order, %Order{} = order, prev_assigned_node}, state) do
    {floor, direction, _state, orders} = ElevatorOperator.get_data()
    own_cost = {Node.self(), CostCalculation.cost(order, floor, direction, orders)}
    {others_costs, _bad_nodes} = GenServer.multi_call(
      Node.list(),
      @name,
      {:get_cost, order},
      @call_timeout
    )

    all_costs = [own_cost | others_costs]
    lowest_cost =
      all_costs
      |> remove_node(prev_assigned_node)
      |> List.keysort(1)
      |> List.first()
    IO.inspect([order, lowest_cost], label: "Assigning order")
    case lowest_cost do
      {best_elevator, _cost} -> OrderDistributor.distribute_new(order, best_elevator)
      nil -> :ok
    end
    {:noreply, state}
  end

  @impl true
  def handle_cast({:new_cab_order, %Order{} = order}, state) do
    OrderDistributor.distribute_new(order, Node.self())
    {:noreply, state}
  end

  # Calls -----------------------------------------------
  @impl true
  def handle_call({:get_cost, %Order{} = order}, _from, state) do
    {floor, direction, _state, orders} = ElevatorOperator.get_data()
    cost = CostCalculation.cost(order, floor, direction, orders)
    {:reply, cost, state}
  end

  # Helper functions ------------------------------------
  defp remove_node(list, node) do
    list -- [{node, list[node]}]
  end
end


defmodule OrderAssigner.CostCalculation do
  @moduledoc """
  Calculating the cost for an elevator to take a given order.

  Uses the following module:
  - `Order`
  """

  @doc """
  Calculating cost for the elevator to take the given order, based on the
  current state of the elevator

  ## Parameters
    - order: Order struct on the form defined in module `Order`
    - floor: Current floor of the elevator, must be integer
    - direction: Current direction of the elevator, must be :up, :down or :stop
    - orders: Map of current assigned order to the elevator

  ## Return
    - cost given as integer
  """
  def cost(%Order{} = order, floor, direction, orders) do
    number_of_orders = orders |> Map.values() |> List.flatten() |> length()
    cond do
      direction == :down and order.floor > floor ->
        number_of_orders + (floor - min_floor(orders)) + (order.floor - min_floor(orders))

      direction == :up and order.floor < floor ->
        number_of_orders + (max_floor(orders) - floor) + (max_floor(orders) - order.floor)

      true ->
        number_of_orders + abs(order.floor - floor)
    end
  end

  defp max_floor(orders) do
    orders
    |> Map.values()
    |> List.flatten()
    |> Enum.sort()
    |> List.last()
  end

  defp min_floor(orders) do
    orders
    |> Map.values()
    |> List.flatten()
    |> Enum.sort()
    |> List.first()
  end
end
