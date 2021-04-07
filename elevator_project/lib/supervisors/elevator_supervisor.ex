defmodule ElevatorSupervisor do
  use Supervisor

  def start_link(_init_arg) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true 
  def init([]) do
    children = [
      Elevator,
      ObstructionPoller,
      FloorPoller,
      Driver
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end