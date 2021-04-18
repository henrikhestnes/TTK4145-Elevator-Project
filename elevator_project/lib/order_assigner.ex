defmodule OrderAssigner do
  use GenServer

  @call_timeout 5_000

  def start_link(_init_arg) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  # API -------------------------------------------------
  def assign_order(%Order{button_type: :cab} = order) do
    order
    |> Map.put(:owner, Node.self())
    |> OrderDistributor.distribute_new()
  end

  def assign_order(%Order{button_type: _hall} = order) do
    lowest_cost =
      all_costs(order)
      |> remove_node(order.owner)
      |> List.keysort(1)
      |> List.first()

    IO.inspect([order, lowest_cost], label: "Assigning order")

    case lowest_cost do
      {best_elevator, _cost} ->
        order
        |> Map.put(:owner, best_elevator)
        |> OrderDistributor.distribute_new()

      nil ->
        :ok
    end
  end

  # Init ------------------------------------------------
  @impl true
  def init(_init_arg) do
    {:ok, []}
  end

  # Callbacks -------------------------------------------
  @impl true
  def handle_call({:get_cost, %Order{} = order}, _from, state) do
    {floor, direction, _state, orders} = ElevatorOperator.get_data()
    cost = OrderAssigner.CostCalculation.cost(order, floor, direction, orders)
    {:reply, cost, state}
  end

  # Helper functions ------------------------------------
  defp all_costs(%Order{} = order) do
    {costs, _bad_nodes} =
      GenServer.multi_call(
        [Node.self() | Node.list()],
        __MODULE__,
        {:get_cost, order},
        @call_timeout
      )

    costs
  end

  defp remove_node(list, node) do
    list -- [{node, list[node]}]
  end
end

defmodule OrderAssigner.CostCalculation do
  # API -------------------------------------------------
  def cost(%Order{} = order, floor, direction, orders) do
    cond do
      direction == :down and order.floor > floor ->
        length(orders) + (floor - min_floor(orders)) + (order.floor - min_floor(orders))

      direction == :up and order.floor < floor ->
        length(orders) + (max_floor(orders) - floor) + (max_floor(orders) - order.floor)

      true ->
        length(orders) + abs(order.floor - floor)
    end
  end

  # Helper functions ------------------------------------
  defp max_floor(orders) do
    orders
    |> Enum.map(fn %Order{} = order -> order.floor end)
    |> Enum.sort()
    |> List.last()
  end

  defp min_floor(orders) do
    orders
    |> Enum.map(fn %Order{} = order -> order.floor end)
    |> Enum.sort()
    |> List.first()
  end
end
