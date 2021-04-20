defmodule Watchdog do
  @moduledoc """
  If a watchdog timer is started for an order and not stopped before the timeout,
  the corresponding order gets reinjected into the system by calling `OrderAssigner.assign_order/1`.
  Keeps track of all active timers through a map from button type and floor to the timer reference.

  Uses the following modules:
  - `Order`
  - `OrderAssigner`
  """

  use GenServer

  @watchdog_timeout 20_000

  def start_link(_init_arg) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  # API -------------------------------------------------
  @doc """
  Starts a watchdog timer for the given order.
  ##  Parameters
    - order: Order to start watchdog timer for :: %Order{}

  ## Return
    - :ok :: atom()
  """
  def start(%Order{} = order) do
    GenServer.cast(__MODULE__, {:start_timer, order})
  end

  @doc """
  Stops the watchdog timer for the given order
  ## Parameters
    - order: Order to stop watchdog timer for :: %Order{}
    
  ## Return
    - :ok :: atom()
  """
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

    timer_ref =
      Process.send_after(
        self(),
        {:expired_order, order},
        @watchdog_timeout
      )

    {:noreply, Map.put(active_timers, {order.button_type, order.floor}, {timer_ref, order.owner})}
  end

  @impl true
  def handle_cast({:stop_timer, %Order{} = order}, active_timers) do
    if active_timers[{order.button_type, order.floor}] do
      {timer_ref, _node} = active_timers[{order.button_type, order.floor}]
      Process.cancel_timer(timer_ref)
      {:noreply, Map.delete(active_timers, {order.button_type, order.floor})}
    else
      {:noreply, active_timers}
    end
  end

  @impl true
  def handle_info({:expired_order, %Order{} = order}, active_timers) do
    if active_timers[{order.button_type, order.floor}] do
      OrderAssigner.assign_order(order)
      {:noreply, Map.delete(active_timers, {order.button_type, order.floor})}
    else
      {:noreply, active_timers}
    end
  end
end
