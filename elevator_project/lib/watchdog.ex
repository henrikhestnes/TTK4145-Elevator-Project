defmodule Watchdog do
  @moduledoc """
  Starts a watchdog for every new hall order distributed, and stops it when the order is completed.
  If a watchdog timer runs out, the corresponding hall order gets redistributed to another elevator.
  Uses the following modules:
  - `OrderAssigner`
  - `Order`
  """

  use GenServer

  @watchdog_timeout 20_000

  def start_link(_init_arg) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  # API -------------------------------------------------
  @doc """
  Casting to the module that a new watchdog should be started, and which elevator serving the order.
  ##  Parameters
    - order: Order struct on the form defined in module `Order` :: %Order{}
  ## Return
    - :ok
  """
  def start(%Order{} = order) do
    GenServer.cast(__MODULE__, {:start_timer, order})
  end

  @doc """
  Casting to the module that the watchdog on the order parameter should be stopped.
  ## Parameters
    - order: Order struct on the form defined in module `Order` :: %Order{}
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
      IO.inspect(order, label: "Stopping timer")
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
      IO.inspect(order, label: "Reinjecting order")
      OrderAssigner.assign_order(order)
      {:noreply, Map.delete(active_timers, {order.button_type, order.floor})}
    else
      {:noreply, active_timers}
    end
  end
end
