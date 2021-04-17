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
    - order: Order struct on the form defined in module `Order`
    - assigned node: Which elevator currently serving the order

  ## Return
    - :ok
  """
  def start(%Order{} = order, assigned_node) do
    GenServer.cast(__MODULE__, {:start_timer, order, assigned_node})
  end

  @doc """
  Casting to the module that the watchdog on the order parameter should be stopped.

  ## Parameters
    - order: Order struct on the form defined in module `Order`

  ## Return
    - :ok
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
  def handle_cast({:start_timer, %Order{} = order, assigned_node}, active_timers) do
    if active_timers[order] do
      {timer_ref, _node} = active_timers[order]
      Process.cancel_timer(timer_ref)
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
      IO.inspect(order, label: "Stopping timer")
      {timer_ref, _node} = active_timers[order]
      Process.cancel_timer(timer_ref)
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
