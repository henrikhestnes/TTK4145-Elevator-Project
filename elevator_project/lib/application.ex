defmodule ElevatorProject.Application do
  use Application

  def start(_type, _args) do
    ElevatorProject.Supervisor.start_link([])
  end
end
