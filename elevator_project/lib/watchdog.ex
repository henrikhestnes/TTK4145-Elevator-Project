defmodule Watchdog do
  use GenServer

  @watchdog_timeout 2_000

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  # API -------------------------------------------------
  def start(%Order{} = order) do
    GenServer.call(__MODULE__, {:start_timer, order})
  end

  def stop(%Order{} = order) do
    GenServer.cast(__MODULE__, {:stop_timer, order})
  end

  # Init ------------------------------------------------
  @impl true
  def init(_args) do
    {:ok, []}
  end

  # Callbacks -------------------------------------------
  @impl true
  def handle_call({:start_timer, %Order{} = order}, _from, active_timers) do
    timer_ref = Process.send_after(self(), {:expired_order, order}, @watchdog_timeout)
    {:reply, {:ok, timer_ref}, active_timers ++ timer_ref}
  end

  @impl true
  def handle_cast({:stop_timer, %Order{} = order}, active_timers) do
    if order.watchdog_ref in active_timers do
      Process.cancel_timer(order.watchdog_ref)
      {:noreply, active_timers -- order.watchdog_ref}
    else
      {:noreply, active_timers}
    end
  end

  @impl true
  def handle_info({:expired_order, %Order{} = order}, active_timers) do
    # reinject order to OrderDistributor,
    IO.puts("Reinjecting order")
    {:noreply, active_timers -- order.watchdog_ref}
  end

  # Helper functions ------------------------------------

end
