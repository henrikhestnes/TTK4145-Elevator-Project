defmodule Watchdog do
  use GenServer

  @watchdog_timeout 20_000

  def start_link(_init_arg) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  # API -------------------------------------------------
  def start(%Order{} = order, assigned_node) do
    GenServer.cast(__MODULE__, {:start_timer, order, assigned_node})
  end

  def stop(%Order{} = order) do
    GenServer.cast(__MODULE__, {:stop_timer, order})
  end

  # Init ------------------------------------------------
  @impl true
  def init(_init_arg) do
    {:ok, %{}}
  end

  # Callbacks -------------------------------------------
  @impl true
  def handle_cast({:start_timer, %Order{} = order, assigned_node}, active_timers) do
    if active_timers[order] do
      stop(order)
    end

    timer_ref = Process.send_after(
      self(),
      {:expired_order, order, assigned_node},
      @watchdog_timeout
    )
    {:noreply, active_timers |> Map.put(order, {timer_ref, assigned_node})}
  end

  @impl true
  def handle_cast({:stop_timer, %Order{} = order}, active_timers) do
    if active_timers[order] do
      IO.inspect(order, label: "stopping timer")
      {timer_ref, _node} = active_timers[order]
      Process.cancel_timer(timer_ref)
      IO.inspect(active_timers)
      {:noreply, active_timers |> Map.delete(order)}
    else
      {:noreply, active_timers}
    end
  end

  @impl true
  def handle_info({:expired_order, %Order{} = order, prev_assigned_node}, active_timers) do
    if active_timers[order] do
      IO.inspect(order, label: "Reinjecting order")
      OrderAssigner.assign_order(order, prev_assigned_node)
      {:noreply, active_timers |> Map.delete(order)}
    else
      {:noreply, active_timers}
    end
  end
end
