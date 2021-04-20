defmodule ElevatorProject.Application do
  @moduledoc false
  
  use Application

  def start(_type, _args) do
    ElevatorProject.Supervisor.start_link([])
  end
end
