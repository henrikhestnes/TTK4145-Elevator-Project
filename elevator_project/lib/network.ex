defmodule Network.Listen do
  @moduledoc """
  `Network.Listen` is responsible for connecting new nodes to the cluster.
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
    - :ok :: atom()
  """
  def init(recv_port) do
    {:ok, socket} =
      :gen_udp.open(recv_port, [:binary, active: false, broadcast: true, reuseaddr: true])

    IO.puts("Started listening on port #{recv_port}")
    listen(socket)
  end

  def listen(socket) do
    {:ok, {_ip, _port, node_name}} = :gen_udp.recv(socket, 0)

    if node_name not in all_nodes() and node_name != "nonode@nohost" do
      IO.puts("Attempting to connect to #{node_name}")
      connect_to(node_name)
    end

    listen(socket)
  end

  def connect_to(node_name, attempt \\ 0)
  def connect_to(node_name, attempt) when attempt < @max_connect_attempts do
    case Node.ping(String.to_atom(node_name)) do
      :pang ->
        connect_to(node_name, attempt + 1)

      :pong ->
        IO.puts("Connected to node #{node_name}")
    end
  end

  def connect_to(node_name, attempt) when attempt >= @max_connect_attempts do
    IO.puts("Gave up connecting to #{node_name}")
  end

  def all_nodes() do
    Enum.map([Node.self() | Node.list()], fn node_name -> to_string(node_name) end)
  end
end

defmodule Network.Broadcast do
  use Task

  @broadcast_sleep_duration 500
  @send_port 0

  def start_link(recv_port) do
    Task.start_link(__MODULE__, :init, [recv_port])
  end

  def init(recv_port) do
    {:ok, socket} =
      :gen_udp.open(@send_port, [:binary, active: false, broadcast: true, reuseaddr: true])

    IO.puts("Started broadcasting to port #{recv_port}")
    broadcast(socket, recv_port)
  end

  def broadcast(socket, recv_port) do
    :gen_udp.send(socket, {255, 255, 255, 255}, recv_port, to_string(Node.self()))
    Process.sleep(@broadcast_sleep_duration)
    broadcast(socket, recv_port)
  end
end

defmodule Network.ConnectionCheck do
  use Task

  @check_sleep_duration 100

  def start_link(_init_arg) do
    Task.start_link(__MODULE__, :check_connection, [[]])
  end

  def check_connection(prev_connected_nodes) do
    current_connected_nodes = Node.list()

    if Enum.empty?(prev_connected_nodes) and not Enum.empty?(current_connected_nodes) do
      OrderDistributor.request_backup()
    end

    Process.sleep(@check_sleep_duration)
    check_connection(current_connected_nodes)
  end
end
