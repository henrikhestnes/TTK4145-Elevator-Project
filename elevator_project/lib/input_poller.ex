defmodule ObstructionPoller do
   @moduledoc """
  `ObstructionPoller` is used to monitor the current state of obstruction.
  """
  @poller_sleep_ms 100

  use Task

  def start_link(_init_arg) do
    Task.start_link(__MODULE__, :poller, [:inactive])
  end

  @doc """
  Updates `ElevatorOperator.obstruction/1` with the current obstruction 
  switch state.

  ## Parameters
    - prev_state: :inactive/:active
  """
  def poller(prev_state) do
    current_state = Driver.get_obstruction_switch_state()
    case {prev_state, current_state} do
      {:inactive, :active} -> ElevatorOperator.obstruction(true)
      {:active, :inactive} -> ElevatorOperator.obstruction(false)
      _ -> :ok
    end

    Process.sleep(@poller_sleep_ms)
    poller(current_state)
  end
end

defmodule FloorPoller do
   @moduledoc """
  `FloorPoller` is used to monitor the current position of the elevator.
  """
  @poller_sleep_ms 100

  use Task

  def start_link(_init_arg) do
    Task.start_link(__MODULE__, :poller, [:between_floors])
  end

  @doc """
  Updates `ElevatorOperator.floor_arrival/1` when the elevator is 
  arriving at a new floor

  ## Parameters
    - prev_state: Can be a Integer floor or :in_between_floors
  """
  def poller(prev_state) do
    current_state = Driver.get_floor_sensor_state()
    if current_state != :between_floors and prev_state == :between_floors do
      ElevatorOperator.floor_arrival(current_state)
    end

    Process.sleep(@poller_sleep_ms)
    poller(current_state)
  end
end

defmodule OrderButtonPoller do
   @moduledoc """
  `OrderButtonPoller` is used to monitor the current state of an
  order button. One task is started for each button in 
  `OrderButtonPoller.Supervisor`. 
  """
  @poller_sleep_ms 100

  use Task

  def start_link(floor, button_type) do
    Task.start_link(__MODULE__, :poller, [floor, button_type, :released])
  end

  @doc """
  `poller/3` retrieves a button state from `Driver.get_order_button_state/2`
  and sends the corresponding order to `OrderAssigner.assign_order/1`
  """
  def poller(floor, button_type, prev_state) do
    current_state = Driver.get_order_button_state(floor, button_type)
    if current_state == 1 and prev_state != 1 do
      OrderAssigner.assign_order(Order.new(button_type, floor))
    end

    Process.sleep(@poller_sleep_ms)
    poller(floor, button_type, current_state)
  end
end
