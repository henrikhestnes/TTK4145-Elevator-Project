defmodule ELEVATOR_SYSTEM.Supervisor do
  @number_of_floors 4

  use Supervisor

  def start_link(node_name, driver_port) do
    Supervisor.start_link(__MODULE__, [node_name, driver_port], name: __MODULE__)
  end

  @impl true
  def init([node_name, driver_port]) do
    children = [
      {HardwareSupervisor, [@number_of_floors, driver_port]},
      {Network.Supervisor, node_name},
      OrderDistributor.Supervisor,
      OrderAssigner.Supervisor,
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
