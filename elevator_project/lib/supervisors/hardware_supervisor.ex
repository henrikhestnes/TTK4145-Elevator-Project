defmodule Hardware.Supervisor do
  use Supervisor

  def start_link(number_of_floors) do
    Supervisor.start_link(__MODULE__, number_of_floors, name: __MODULE__)
  end

  @impl true
  def init(number_of_floors) do
    :os.cmd('gnome-terminal -x ../../../SimElevatorServer')
    Process.sleep(100)

    children = [
      {Driver, []},
      Elevator,
      ObstructionPoller,
      FloorPoller,
      {OrderButtonPoller.Supervisor, number_of_floors}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
