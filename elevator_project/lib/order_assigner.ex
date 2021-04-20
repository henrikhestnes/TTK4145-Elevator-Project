defmodule OrderAssigner do
  @moduledoc """
  Assigns orders to the best suited elevator.

  Uses the following modules:
  - `Order`
  - `OrderDistributor`
  - `OrderAssigner.CostCalculation`
  """

  use GenServer

  @call_timeout 1_000

  @doc false
  def start_link(_init_arg) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  # API -------------------------------------------------
  @doc """
  Assigns an order to the best suited elevator. Unless the elevator
  is running without being connected to the node cluster, the same
  elevator will not get the same order twice in a row. Calls
  `OrderDistributor.distribute_new/1` after the order is assigned.
  ## Parameters
    - order: Order to be assgined :: %Order{}

  ## Return
    - :ok :: atom()
  """
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

    case lowest_cost do
      {best_elevator, _cost} ->
        order
        |> Map.put(:owner, best_elevator)
        |> OrderDistributor.distribute_new()

      _no_replies ->
        order
        |> Map.put(:owner, Node.self())
        |> OrderDistributor.distribute_new()
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
    cost = OrderAssigner.CostCalculation.cost(order)
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
  @moduledoc """
  Calculates the cost for the elevator to take a given order, based on
  the current state of the elevator.

  Uses the following modules:
  - `Order`
  - `ElevatorOperator`
  """

  @doc """
  Calls `ElevatorOperator.get_data/0` to retrieve the current state of the
  elevator, and calculates the cost of taking the order.
  ## Parameters
    - order: Order to be calculated cost for :: %Order{}

  ## Return
    - Cost of the elevator :: integer()
  """
  # API -------------------------------------------------
  def cost(%Order{} = order) do
    {floor, direction, _state, orders} = ElevatorOperator.get_data()

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
