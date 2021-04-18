defmodule OrderDistributor.Supervisor do
  use Supervisor

  def start_link(_init_arg) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      OrderDistributor,
      Orders
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
