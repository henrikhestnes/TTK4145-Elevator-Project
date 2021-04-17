defmodule Network.Init do
@moduledoc """
`Network.Init` is responsible for creating a node name and retrieving 
the ip adress.
"""
  @cookie :heisbois
  @port 6000
  @receive_timeout 100
  @sleep_duration 50

  use Task

  def start_link(node_name) do
    Task.start_link(__MODULE__, :start_node, [node_name])
  end

  @doc """
  `start_node/1` retrieves the ip, starts a node with
  the name it creates and sets the cookie.

  ## Parameters 
    - node_name:  Node name :: String
  """
  def start_node(node_name) do
    # Unable to start node => run 'epmd -daemon' in terminal
    ip = get_ip() |> :inet.ntoa() |> to_string()
    name = node_name <> "@" <> ip
    Node.start(String.to_atom(name))
    Node.set_cookie(@cookie)
  end

  defp get_ip() do
    {:ok, socket} = :gen_udp.open(@port, [:binary, active: false, broadcast: true, reuseaddr: true])
    :gen_udp.send(socket, {255,255,255,255}, @port, "dummy packet")

    ip = case :gen_udp.recv(socket, 0, @receive_timeout) do
      {:ok, {ip, _port, _data}} -> ip
      {:error, _reason} ->
        :gen_udp.close(socket)
        Process.sleep(@sleep_duration)
        get_ip()
    end

    :gen_udp.close(socket)
    ip
  end
end

defmodule Network.Listen do
@moduledoc """
`Network.Listen` is responsible for connecting new nodes to the cluster.
"""
  @max_connect_attempts 10

  use Task

  def start_link(recv_port) do
    Task.start_link(__MODULE__, :init, [recv_port])
  end

  @doc """
  `init/1` opens a socket and starts listening by calling `listen/1`.

  ## Parameters
    - recv_port: Port number :: Integer 
  """
  def init(recv_port) do
    {:ok, socket} = :gen_udp.open(recv_port, [:binary, active: false, broadcast: true, reuseaddr: true])
    Process.sleep(2_000)
    IO.puts("Started listening on port #{recv_port}")
    listen(socket)
  end

  @doc """
  `listen/1` listens for new nodes and connects the new node to 
  the current cluster. 

  ## Parameters 
    - socket: Socket number :: Integer 
  """
  def listen(socket) do
    {:ok, {_ip, _port, node_name}} = :gen_udp.recv(socket, 0)

    if node_name not in all_nodes() and node_name != "nonode@nohost" do
      IO.puts("Attempting to connect to #{node_name}")
      connect_to(node_name)
    end

    listen(socket)
  end

  @doc """
  `connect_to/2` connects a node to the cluster. 

  ## Parameters 
    - node_name: Node name :: String 
    - attemt: Number of connection attemts :: Integer
  """
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

  @doc """
  Returns list of all nodes.
  """
  def all_nodes() do
    Enum.map([Node.self() | Node.list()], fn node_name -> to_string(node_name) end)
  end
end


defmodule Network.Broadcast do
  @moduledoc """
  `Network.Broadcast` is responsible for broadcasting the node name, so that
  the node can be discovered by other nodes. 
  """
  @wait_duration 500
  @send_port 0

  use Task

  def start_link(recv_port) do
    Task.start_link(__MODULE__, :init, [recv_port])
  end

  @doc """
  `init/1` initializes `broadcast/2` with the correct socket and receive 
  port

  ## Parameters
    - recv_port: port number :: Integer
  """
  def init(recv_port) do
    {:ok, socket} = :gen_udp.open(@send_port, [:binary, active: false, broadcast: true, reuseaddr: true])
    Process.sleep(2_000)
    IO.puts("Started broadcasting to port #{recv_port}")
    broadcast(socket, recv_port)
  end

  @doc """
  `broadcast/2` broadcasts the node name.

  ## Parameters 
    - socket: Socket number :: Integer 
    - recv_port: Port number :: Integer
  """
  def broadcast(socket, recv_port) do
    :gen_udp.send(socket, {255,255,255,255}, recv_port, to_string(Node.self()))
    Process.sleep(@wait_duration)
    broadcast(socket, recv_port)
  end
end

defmodule Network.ConnectionCheck do
@moduledoc """

"""
  @check_sleep_ms 100

  use Task

  def start_link(_init_arg) do
    Task.start_link(__MODULE__, :check_connection, [[]])
  end

  def check_connection(prev_connected_nodes) do
    current_connected_nodes = Node.list()
    if Enum.empty?(prev_connected_nodes) and not Enum.empty?(current_connected_nodes) do
      OrderDistributor.request_backup()
    end

    Process.sleep(@check_sleep_ms)
    check_connection(current_connected_nodes)
  end
end
