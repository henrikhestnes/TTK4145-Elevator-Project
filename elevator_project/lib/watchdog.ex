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
    if active_timers[{order.button_type, order.floor}] do
      {timer_ref, _node} = active_timers[{order.button_type, order.floor}]
      Process.cancel_timer(timer_ref)
    end

    timer_ref = Process.send_after(
      self(),
      {:expired_order, order},
      @watchdog_timeout
    )
    {:noreply, active_timers |> Map.put({order.button_type, order.floor}, {timer_ref, order.owner})}
  end

  @impl true
  def handle_cast({:stop_timer, %Order{} = order}, active_timers) do
    if active_timers[{order.button_type, order.floor}] do
      IO.inspect(order, label: "Stopping timer")
      {timer_ref, _node} = active_timers[{order.button_type, order.floor}]
      Process.cancel_timer(timer_ref)
      {:noreply, active_timers |> Map.delete({order.button_type, order.floor})}
    else
      {:noreply, active_timers}
    end
  end

  @impl true
  def handle_info({:expired_order, %Order{} = order}, active_timers) do
    if active_timers[{order.button_type, order.floor}] do
      IO.inspect(order, label: "Reinjecting order")
      OrderAssigner.assign_order(order)
      {:noreply, active_timers |> Map.delete({order.button_type, order.floor})}
    else
      {:noreply, active_timers}
    end
  end
end
