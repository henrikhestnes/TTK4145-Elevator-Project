defmodule ElevatorProject.Supervisor do
  use Supervisor

  @number_of_floors 8
  @node_name "heis"

## FOR RUNNING THE SIMULATOR
  # def start_link(node_name, driver_port) do
  #   Supervisor.start_link(__MODULE__, [node_name, driver_port], name: __MODULE__)
  # end

  # @impl true
  # def init([node_name, driver_port]) do
  #   children = [
  #     {Network.Supervisor, node_name},
  #     OrderDistributor.Supervisor,
  #     OrderAssigner.Supervisor,
  #     {HardwareSupervisor, [@number_of_floors, driver_port]}
  #   ]

  #   Supervisor.init(children, strategy: :one_for_one)
  # end

## FOR RUNNING THE PHYSICAL ELEVATOR
  def start_link([]) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init([]) do
    children = [
      {Network.Supervisor, @node_name},
      OrderDistributor.Supervisor,
      OrderAssigner.Supervisor,
      {HardwareSupervisor, @number_of_floors}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
