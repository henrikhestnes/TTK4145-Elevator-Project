defmodule OrderBackup do
  use GenServer

  @enforce_keys [:cab_calls, :hall_calls]
  defstruct [:cab_calls, :hall_calls]

  # :cab_calls %{node => [cab_order1, cab_order2, ...]}
  # :hall_calls [hall_order1, hall_order2, ...]

  # API ----------------------------------------------
  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get() do
    GenServer.call(__MODULE__, :get_backup)
  end

  def new(%Order{} = order, node) do
    case order.button_type do
      :cab  -> GenServer.cast(__MODULE__, {:new_cab_order, order, node})
      _hall -> GenServer.cast(__MODULE__, {:new_hall_order, order})
    end
  end

  def delete(%Order{} = order, node) do
    case order.button_type do
      :cab  -> GenServer.cast(__MODULE__, {:delete_cab_order, order, node})
      _hall -> GenServer.cast(__MODULE__, {:delete_hall_order, order})
    end
  end

  def merge(backups) do
    GenServer.cast(__MODULE__, {:merge, backups})
  end

  # Init -----------------------------------------------
  def init(_init_arg) do
    {:ok, %OrderBackup{cab_calls: %{}, hall_calls: []}}
  end

  # Casts -----------------------------------------------
  def handle_cast({:new_cab_order, %Order{} = order, node}, %OrderBackup{} = backup) do
    current_calls = Map.get(backup.cab_calls, node, [])
    updated_calls = Enum.uniq(current_calls ++ [order])

    cab_calls = Map.put(backup.cab_calls, node, updated_calls)
    {:noreply, %{backup | cab_calls: cab_calls}}
  end

  def handle_cast({:new_hall_order, %Order{} = order}, %OrderBackup{} = backup) do
    hall_calls = Enum.uniq(backup.hall_calls ++ [order])
    {:noreply, %{backup | hall_calls: hall_calls}}
  end

  def handle_cast({:delete_cab_order, %Order{} = order, node}, %OrderBackup{} = backup) do
    current_calls = Map.get(backup.cab_calls, node, [])
    updated_calls = Enum.uniq(current_calls -- [order])

    cab_calls = Map.put(backup.cab_calls, node, updated_calls)
    {:noreply, %{backup | cab_calls: cab_calls}}
  end

  def handle_cast({:delete_hall_order, %Order{} = order}, %OrderBackup{} = backup) do
    hall_calls = Enum.uniq(backup.hall_calls -- [order])
    {:noreply, %{backup | hall_calls: hall_calls}}
  end

  def handle_cast({:merge, backups}, _backup) do
    number_of_backups = length(backups)

    merged_cab_calls = backups
    |> Enum.map(fn %OrderBackup{} = backup -> backup.cab_calls end)
    |> merge_cab_calls(number_of_backups)


    merged_hall_calls = backups
    |> Enum.map(fn %OrderBackup{} = backup -> backup.hall_calls end)
    |> List.flatten()
    |> Enum.uniq()

    merged_backup = %OrderBackup{
      cab_calls: merged_cab_calls,
      hall_calls: merged_hall_calls
    }
    {:noreply, merged_backup}
  end

  # Calls -----------------------------------------------
  def handle_call(:get_backup, _from, %OrderBackup{} = backup) do
    {:reply, backup, backup}
  end

  # Helper functions ------------------------------------
  defp merge_cab_calls(cab_calls, number_of_backups, current_merge \\ %{}, index \\ 0) do
    if index < number_of_backups do
      new_merge = Map.merge(
        current_merge,
        Enum.at(cab_calls, index, %{}),
        fn _node, merged_calls, new_calls -> Enum.uniq(merged_calls ++ new_calls) end
      )
      merge_cab_calls(cab_calls, number_of_backups, new_merge, index + 1)
    else
      current_merge
    end
  end


  # defp merge(old_backup, backups) do
  #   [new_backup | remaining_backups] = backups
  #   []
  #   new_backup = Enum.filter(next_backup, fn el -> !Enum.member?(old_backup, el) end) ++ old_backup
  #   case remaining_backups do
  #     []                ->
  #     remaining_backups -> merge(new_backup, remaining_backups)
  #   end
  # end

  # def merge(backups) do
  #   [first_backup | remaining_backups] = backups
  #   merge(first_backup, remaining_backups)
  # end

  # def merge(backups) do
  #   new_backup = OrderBackup{}
  # end

  # def merge(current_backup, new_backup)
  #   Enum.each(new_backup.cab_calls, fn({key, value}) ->


  # Map.merge(current_backup, new_backup, fn _k, )
end
