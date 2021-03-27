defmodule OrderBackup do
  use GenServer

  @enforce_keys [:cab_calls, :hall_calls]
  defstruct [:cab_calls, :hall_calls]

  # API
  def start_link do
    GenServer.start_link(__MODULE__, %OrderBackup{cab_calls: [], hall_calls: []})
  end

  def get() do
    {reply, :ok, state} = GenServer.call(__MODULE__, :get_orders)
    state
  end

  def add_hall_order(order) do
    Agent.update(__MODULE__, fn backup -> Enum.uniq([order | backup]) end)
  end

  def remove_order(order) do
    Agent.update(__MODULE__, fn backup -> Enum.filter(backup, fn el -> el != order end) end)
  end

  defp merge(old_backup, backups) do
    [next_backup | remaining_backups] = backups
    new_backup = Enum.filter(next_backup, fn el -> !Enum.member?(old_backup, el) end) ++ old_backup
    case remaining_backups do
      []                -> Agent.update(__MODULE__, fn _backup -> new_backup end)
      remaining_backups -> merge(new_backup, remaining_backups)
    end
  end

  def merge(backups) do
    [first_backup | remaining_backups] = backups
    merge(first_backup, remaining_backups)
  end

  def handle_call(:get_hall_calls, _from, state) do
    {:reply, :ok, state}
  end

  def handle_call(:add_hall_order, _from, state) do

  end
end
