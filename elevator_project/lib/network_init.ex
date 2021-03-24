defmodule NetworkInit do
  @ip_file "..."
  @read_error_timeout 1_000

  use Task

  def start_link do
    Task.start_link(__MODULE__, :init, [])
  end

  def init() do

  end

  def connect() do

  end

  def read_ip_file() do
    case File.open(@ip_file, [:read]) do
      {:ok, ip_file} ->
        {:ok, ip_string} = File.read(ip_file)
        ip_list = String.split(ip_string, "\n", trim: true)
        {:ok, ip_list}
      {:error, reason} ->
        {:error, reason}
    end
  end
end
