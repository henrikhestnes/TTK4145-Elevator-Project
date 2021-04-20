defmodule ObstructionPoller do
  @moduledoc """
  Monitors the state of the obstruction switch, and signals `ElevatorOperator` if
  the state changes.

  Uses the following modules:
    - Driver
    - ElevatorOperator
  """
  
  use Task

  @poller_sleep_duration 100

  @doc false
  def start_link(_init_arg) do
    Task.start_link(__MODULE__, :poller, [:inactive])
  end

  @doc """
  Calls `ElevatorOperator.obstruction/1` with the current obstruction
  switch state if the state changes.
  ## Parameters
    - prev_state: State of the obstruction switch sensor. Can be :inactive or :active :: atom()

  ## Return
    - no_return
  """
  def poller(prev_state) do
    current_state = Driver.get_obstruction_switch_state()

    case {prev_state, current_state} do
      {:inactive, :active} -> ElevatorOperator.obstruction(true)
      {:active, :inactive} -> ElevatorOperator.obstruction(false)
      _ -> :ok
    end

    Process.sleep(@poller_sleep_duration)
    poller(current_state)
  end
end

defmodule FloorPoller do
  @moduledoc """
  Monitors the state of the floor sensor, and signals `ElevatorOperator` if
  the elevator arrives at a floor.

  Uses the following modules:
    - Driver
    - ElevatorOperator
  """
  use Task

  @poller_sleep_duration 100

  @doc false
  def start_link(_init_arg) do
    Task.start_link(__MODULE__, :poller, [:between_floors])
  end

  @doc """
  Calls `ElevatorOperator.floor_arrival/1` when the elevator is
  arriving at a new floor.
  ## Parameters
    - prev_state: State of the floor sensor. Can be the floor number or :in_between_floors :: integer() | atom()

  ## Return
    - no_return
  """
  def poller(prev_state) do
    current_state = Driver.get_floor_sensor_state()

    if current_state != :between_floors and prev_state == :between_floors do
      ElevatorOperator.floor_arrival(current_state)
    end

    Process.sleep(@poller_sleep_duration)
    poller(current_state)
  end
end

defmodule OrderButtonPoller do
  @moduledoc """
  Used to monitor the state of one order button, and signals
  `OrderAssigner` if the button is pressed. One poller is started
  for each button in `OrderButtonPoller.Supervisor`.

  Uses the following modules:
    - Driver
    - Order
    - OrderAssigner
  """
  use Task

  @poller_sleep_duration 100

  @doc false
  def start_link(floor, button_type) do
    Task.start_link(__MODULE__, :poller, [floor, button_type, :released])
  end

  @doc """
  Retrieves the state of an order button. Uses `OrderAssigner.assign_order/1`
  to signals assignment of the order if the button is pressed.
  ## Parameters
    - floor: Floor of the order button :: integer()
    - button_type: Button type of the order button. Can be :cab, :hall_up or :hall_down :: atom()
    - prev_state: State of the order button. Can be 0 or 1 :: boolean()

  ## Return
    - no_return
  """
  def poller(floor, button_type, prev_state) do
    current_state = Driver.get_order_button_state(floor, button_type)

    if current_state == 1 and prev_state != 1 do
      OrderAssigner.assign_order(Order.new(button_type, floor))
    end

    Process.sleep(@poller_sleep_duration)
    poller(floor, button_type, current_state)
  end
end
