defmodule Network.Supervisor do
  @moduledoc false
  
  use Supervisor

  @cookie :heisbois
  @send_port 6000
  @receive_port 8000
  @receive_timeout 100
  @broadcast_sleep_duration 50

  def start_link(node_name) do
    Supervisor.start_link(__MODULE__, node_name, name: __MODULE__)
  end

  @impl true
  def init(node_name) do
    # Unable to start node => run 'epmd -daemon' in terminal
    ip = get_ip() |> :inet.ntoa() |> to_string()
    name = node_name <> "@" <> ip
    Node.start(String.to_atom(name))
    Node.set_cookie(@cookie)

    children = [
      {Network.Listen, @receive_port},
      {Network.Broadcast, @receive_port},
      Network.ConnectionCheck
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp get_ip() do
    {:ok, socket} =
      :gen_udp.open(@send_port, [:binary, active: false, broadcast: true, reuseaddr: true])

    :gen_udp.send(socket, {255, 255, 255, 255}, @send_port, "dummy packet")

    ip =
      case :gen_udp.recv(socket, 0, @receive_timeout) do
        {:ok, {ip, _port, _data}} ->
          ip

        {:error, _reason} ->
          :gen_udp.close(socket)
          Process.sleep(@broadcast_sleep_duration)
          get_ip()
      end

    :gen_udp.close(socket)
    ip
  end
end
