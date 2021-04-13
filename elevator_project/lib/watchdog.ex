defmodule Watchdog do
  use GenServer

  @watchdog_timeout 20_000

  def start_link(_init_arg) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  # API -------------------------------------------------
  def start(%Order{} = order) do
    GenServer.cast(__MODULE__, {:start_timer, order})
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
  def handle_cast({:start_timer, %Order{} = order}, active_timers) do
    if active_timers[order] do
      stop(order)
    end

    timer_ref = Process.send_after(self(), {:expired_order, order}, @watchdog_timeout)
    {:noreply, active_timers |> Map.put(order, timer_ref)}
  end

  @impl true
  def handle_cast({:stop_timer, %Order{} = order}, active_timers) do
    timer_ref = active_timers[order]

    if timer_ref do
      Process.cancel_timer(timer_ref)
      {:noreply, active_timers |> Map.delete(order)}
    else
      {:noreply, active_timers}
    end
  end

  @impl true
  def handle_info({:expired_order, %Order{} = order}, active_timers) do
    if active_timers[order] do
      IO.puts("Reinjecting order")
      OrderAssigner.assign_order(order)
      {:noreply, active_timers |> Map.delete(order)}
    else
      {:noreply, active_timers}
    end
  end
end
