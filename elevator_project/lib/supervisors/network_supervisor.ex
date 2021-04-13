defmodule Network.Supervisor do
  @receive_port 8000
  use Supervisor

  # def start_link(node_name) do
  #   Supervisor.start_link(__MODULE__, node_name, name: __MODULE__)
  # end

  # @impl true
  # def init(node_name) do
  #   children = [
  #     {Network.Init, node_name},
  #     {Network.Listen, @receive_port},
  #     {Network.Broadcast, @receive_port}
  #   ]

  #   Supervisor.init(children, strategy: :one_for_one)
  # end

  def start_link(node_name) do
    Supervisor.start_link(__MODULE__, node_name, name: __MODULE__)
  end

  @impl true
  def init(node_name) do
    children = [
      {Network.Init, node_name},
      {Network.Listen, @receive_port},
      {Network.Broadcast, @receive_port},
      Network.ConnectionCheck
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
