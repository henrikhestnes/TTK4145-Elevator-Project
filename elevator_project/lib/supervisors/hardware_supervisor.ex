defmodule HardwareSupervisor do
  use Supervisor

  def start_link([number_of_floors, driver_port]) do
    Supervisor.start_link(__MODULE__, [number_of_floors, driver_port], name: __MODULE__)
  end

  @impl true
  def init([number_of_floors, driver_port]) do
    :os.cmd('gnome-terminal -x ~/SimElevatorServer --port #{driver_port} --numfloors #{number_of_floors}')
    Process.sleep(100)

    children = [
      {Driver, [{127,0,0,1}, driver_port]},
      {OrderButtonPoller.Supervisor, number_of_floors},
      ElevatorOperator,
      ObstructionPoller,
      FloorPoller
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
