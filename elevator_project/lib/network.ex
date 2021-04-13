defmodule Network do
  @max_call_attempts 5
  @default_call_timeout 100

  def multi_call(recipitens, name, request, timeout \\ @default_call_timeout, current_replies \\ [], attempt \\ 0) do
    {new_replies, bad_nodes} = GenServer.multi_call(
      recipitens,
      name,
      request,
      timeout
    )

    replies = current_replies ++ new_replies
    if not Enum.empty?(bad_nodes) and attempt < @max_call_attempts do
      new_recipients = Enum.filter(bad_nodes, fn node -> node in Node.list() end)
      multi_call(new_recipients, name, request, timeout, replies, attempt + 1)
    end

    replies
  end
end

defmodule Network.Init do
  @cookie :heisbois
  @port 6000
  @receive_timeout 100
  @sleep_duration 100

  use Task

  def start_link(node_name) do
    Task.start_link(__MODULE__, :start_node, [node_name])
  end

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
  @max_connect_attempts 5

  use Task

  def start_link(recv_port) do
    Task.start_link(__MODULE__, :init, [recv_port])
  end

  def init(recv_port) do
    {:ok, socket} = :gen_udp.open(recv_port, [:binary, active: false, broadcast: true, reuseaddr: true])
    IO.puts("Started listening on port #{recv_port}")
    listen(socket)
  end

  def listen(socket) do
    {:ok, {_ip, _port, node_name}} = :gen_udp.recv(socket, 0)

    if node_name not in all_nodes() do
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
        OrderDistributor.request_backup()
        :ok
    end
  end

  def connect_to(node_name, attempt) when attempt == @max_connect_attempts do
    IO.puts("Gave up connecting to #{node_name}")
  end

  def all_nodes() do
    Enum.map([Node.self() | Node.list()], fn node_name -> to_string(node_name) end)
  end
end


defmodule Network.Broadcast do
  @wait_duration 100
  @send_port 0

  use Task

  def start_link(recv_port) do
    Task.start_link(__MODULE__, :init, [recv_port])
  end

  def init(recv_port) do
    {:ok, socket} = :gen_udp.open(@send_port, [:binary, active: false, broadcast: true, reuseaddr: true])
    IO.puts("Started broadcasting to port #{recv_port}")
    broadcast(socket, recv_port)
  end

  def broadcast(socket, recv_port) do
    :gen_udp.send(socket, {255,255,255,255}, recv_port, to_string(Node.self()))
    Process.sleep(@wait_duration)
    broadcast(socket, recv_port)
  end
end

defmodule Network.ConnectionCheck do
  @check_sleep_ms 100

  use Task

  def start_link(_init_arg) do
    Task.start_link(__MODULE__, :check_connection, [[]])
  end

  def check_connection(prev_connected_nodes) do
    current_connected_nodes = Node.list()
    case {prev_connected_nodes, current_connected_nodes} do
      {[], []}              -> :no_request
      {[], _non_empty_list} ->
        OrderDistributor.request_backup()
      _ -> :ok
    end

    Process.sleep(@check_sleep_ms)
    check_connection(current_connected_nodes)
  end
end
