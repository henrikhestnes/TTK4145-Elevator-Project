defmodule Network.Init do
  @cookie :heisbois
  @port 6000
  @receive_timeout 100
  @wait_duration 100

  def start_node(node_name) do
    #Unable to start node => run 'epmd -daemon' in terminal
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
        Process.sleep(@wait_duration)
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
    listen(socket)
  end

  def listen(socket) do
    {:ok, {_ip, _port, node_name}} = :gen_udp.recv(socket, 0)

    if node_name not in all_nodes() do
      connect_to(node_name)
    end

    listen(socket)
  end

  def connect_to(node_name, counter \\ 0) when counter <= @max_connect_attempts do
    case Node.ping(String.to_atom(node_name)) do
      :pang ->
        IO.puts("Failed to connect to node #{node_name}")
        connect_to(node_name, counter + 1)
      :pong ->
        IO.puts("Connected to node #{node_name}")
        :ok
    end
  end

  defp all_nodes() do
    Enum.map([Node.self() | Node.list()], fn node_name -> to_string(node_name) end)
  end
end


defmodule Network.Broadcast do
  @wait_duration 1_000
  @send_port 0

  use Task

  def start_link(recv_port) do
    Task.start_link(__MODULE__, :init, [recv_port])
  end

  def init(recv_port) do
    {:ok, socket} = :gen_udp.open(@send_port, [:binary, active: false, broadcast: true, reuseaddr: true])
    broadcast(socket, recv_port)
  end

  def broadcast(socket, recv_port) do
    :gen_udp.send(socket, {255,255,255,255}, recv_port, to_string(Node.self()))
    Process.sleep(@wait_duration)
    broadcast(socket, recv_port)
  end
end
