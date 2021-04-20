defmodule Network.Listen do
  @moduledoc """
  Listens for messages from other nodes, and attempts to
  connect to the cluster upon reception.
  """
  use Task

  @max_connect_attempts 10

  def start_link(recv_port) do
    Task.start_link(__MODULE__, :init, [recv_port])
  end

  @doc """
  `init/1` opens a socket and starts listening by calling `listen/1`.
  ## Parameters
    - recv_port: Port number :: integer()
  ## Return
    - no_return
  """
  def init(recv_port) do
    {:ok, socket} =
      :gen_udp.open(recv_port, [:binary, active: false, broadcast: true, reuseaddr: true])

    IO.puts("Started listening on port #{recv_port}")
    listen(socket)
  end

  defp listen(socket) do
    {:ok, {_ip, _port, node_name}} = :gen_udp.recv(socket, 0)

    if node_name not in all_nodes() and node_name != "nonode@nohost" do
      IO.puts("Attempting to connect to #{node_name}")
      connect_to(node_name)
    end

    listen(socket)
  end

  defp connect_to(node_name, attempt \\ 0)

  defp connect_to(node_name, attempt) when attempt < @max_connect_attempts do
    case Node.ping(String.to_atom(node_name)) do
      :pang ->
        connect_to(node_name, attempt + 1)

      :pong ->
        IO.puts("Connected to node #{node_name}")
    end
  end

  defp connect_to(node_name, attempt) when attempt >= @max_connect_attempts do
    IO.puts("Gave up connecting to #{node_name}")
  end

  defp all_nodes() do
    Enum.map([Node.self() | Node.list()], fn node_name -> to_string(node_name) end)
  end
end

defmodule Network.Broadcast do
  @moduledoc """
  Broadcasts own node name, so that
  the node can be discovered by other nodes.
  """
  use Task

  @broadcast_sleep_duration 500
  @send_port 0

  def start_link(recv_port) do
    Task.start_link(__MODULE__, :init, [recv_port])
  end

  @doc """
  `init/1` initializes `broadcast/2` with a socket and the port
  `Network.Listen` is listening on.
  ## Parameters
    - recv_port: Port number `Network.Listen` is listening on :: integer()
  ## Return
    - no_return
  """
  def init(recv_port) do
    {:ok, socket} =
      :gen_udp.open(@send_port, [:binary, active: false, broadcast: true, reuseaddr: true])

    IO.puts("Started broadcasting to port #{recv_port}")
    broadcast(socket, recv_port)
  end

  defp broadcast(socket, recv_port) do
    :gen_udp.send(socket, {255, 255, 255, 255}, recv_port, to_string(Node.self()))
    Process.sleep(@broadcast_sleep_duration)
    broadcast(socket, recv_port)
  end
end

defmodule Network.ConnectionCheck do
  @moduledoc """
  Evaluates if the elevator must request a backup, by checking if the node
  newly connected to the cluster.

  Uses the modules:
    - OrderDistributor
  """
  use Task

  @check_sleep_duration 100

  def start_link(_init_arg) do
    Task.start_link(__MODULE__, :check_connection, [[]])
  end

  @doc """
  Checks the current list of connected nodes and compares it to the previous list of nodes. If
  the list goes from empty to not empty, the node requests a backup by calling
  ´OrderDistributor.request_backup/0´.
  ## Parameters
    - prev_connected_nodes: list of the previously connected nodes :: list()
  ## Return
    - no_return
  """
  def check_connection(prev_connected_nodes) do
    current_connected_nodes = Node.list()

    if Enum.empty?(prev_connected_nodes) and not Enum.empty?(current_connected_nodes) do
      OrderDistributor.request_backup()
    end

    Process.sleep(@check_sleep_duration)
    check_connection(current_connected_nodes)
  end
end
