defmodule OrderBackup do
   use Agent

  @valid_order [:cab, :hall_down, :hall_up]

  # API
  def start_link do
    Agent.start_link(fn -> []]
  end

  def order_map do
    Agent.get(__MODULE__, fn orders -> orders end)
  end

  defp update_backup(order) do
      case order[:button_type] do
        :cab        -> 
          Agent.update(__MODULE__, fn list -> List.update(map, button_type, [], fn list -> Enum.uniq([floor | list]) end) end)
        :hall_up    ->
        :hall_down  -> 
      end
  end

  defp merge_backups(old_backup, backups) do
    [next_backup | remaining_backups] = backups
    new_backup = Enum.filter(next_backup, fn el -> !Enum.member?(old_backup, el) end) ++ old_backup
    OrderBackup.update_backup(cab, hall_down, hall_up)
    case remaining_backups do
      []                -> OrderBackup.update_backup(new_backup)
      remaining_backups -> compare_backups(new_backup, remaining_backups)
    end
  end

  def merge_backups(backups) do
    [first_backup | remaining_backups] = backups
    compare_backups(first_backup, remaining_backups)
  end
end
end