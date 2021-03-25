defmodule OrderBackup do
   use Agent

  @valid_order [:cab, :hall_down, :hall_up]

  # API
  def start_link do
    Agent.start_link(fn -> [] end)
  end

  def order_map do
    Agent.get(__MODULE__, fn orders -> orders end)
  end

  defp add_order(order) do
    Agent.update(__MODULE__, fn backup -> Enum.uniq([order | backup]) end)
  end

  def remove_order(order) do
    Agent.update(__MODULE__, fn backup -> Enum.filter(backup, fn el -> el != order end) end)
  end

  defp merge(old_backup, backups) do
    [next_backup | remaining_backups] = backups
    new_backup = Enum.filter(next_backup, fn el -> !Enum.member?(old_backup, el) end) ++ old_backup
    case remaining_backups do
      []                -> Agent.update(__MODULE__, new_backup)
      remaining_backups -> merge(new_backup, remaining_backups)
    end
  end

  def merge(backups) do
    [first_backup | remaining_backups] = backups
    merge(first_backup, remaining_backups)
  end
end