defmodule ElevatorOperator do
  @moduledoc """
  Finite state machine responible for running one elevator, implemented using the behaviour GenStateMachine.
  The state machine has the states `idle`, `moving` and `door_open`, and keeps track of the current floor,
  moving direction, obstructed sensor state and door timer.

  Uses the following modules:
  - `Orders`
  - `Driver`
  - `OrderDistributor`
  """

  use GenStateMachine

  alias ElevatorOperator, as: Elevator

  @enforce_keys [:floor, :direction, :is_obstructed, :timer_ref]
  defstruct [:floor, :direction, :is_obstructed, :timer_ref]

  def start_link(_init_arg) do
    GenStateMachine.start_link(__MODULE__, [], name: __MODULE__)
  end

  # API -------------------------------------------------
  @doc """
  Signals the push of an order button.
  ## Parameters
    - order: Order corresponding to pressed order button :: %Order{}

  ## Return
    - no_return
  """
  def order_button_press(%Order{} = order) do
    GenStateMachine.cast(__MODULE__, {:request_button_press, order})
  end

  @doc """
  Signals that the elevator has arrived at a floor.
  ## Parameters
    - floor: The floor the elevator has arrived at :: integer()
  
  ## Return
    - no_return
  """
  def floor_arrival(floor) do
    GenStateMachine.cast(__MODULE__, {:floor_arrival, floor})
  end

  @doc """
  Signals that the state of the obstruction switch has changed.
  ## Return
    - no_return
  """
  def obstruction(is_obstructed) do
    GenStateMachine.cast(__MODULE__, {:obstruction_sensor_update, is_obstructed})
  end

  @doc """
  Signals that the door timer has been started or stopped,
  and changes the timer reference.
  ## Return
    - no_return
  """
  def timer_update(timer_ref) do
    GenStateMachine.cast(__MODULE__, {:timer_update, timer_ref})
  end

  @doc """
  Returns the current state of the elevator.
  ## Return
  - Current state of the elevator, tuple of form
  {floor, direction, state, orders} :: {integer(), atom(), atom(), %MapSet}
  """
  def get_data() do
    GenStateMachine.call(__MODULE__, :get_data)
  end

  # Initialization and termination callbacks ------------
  def init(_init_arg) do
    if not Enum.empty?(Node.list()) do
      OrderDistributor.request_backup()
    end

    case Driver.get_floor_sensor_state() do
      :between_floors ->
        Driver.set_door_open_light(:off)
        Driver.set_motor_direction(:down)

        e = %Elevator{
          floor: nil,
          direction: :down,
          is_obstructed: false,
          timer_ref: nil
        }

        {:ok, :moving, e}

      floor ->
        e = %Elevator{
          floor: floor,
          direction: :stop,
          is_obstructed: false,
          timer_ref: nil
        }

        {:ok, :idle, e}
    end
  end

  def terminate(_reason, _state, _data) do
    Driver.set_motor_direction(:stop)
  end

  # Order button press callbacks ------------------------
  def handle_event(:cast, {:request_button_press, %Order{} = order}, :door_open, %Elevator{} = e) do
    if e.floor == order.floor do
      OrderDistributor.distribute_completed(order)
      ElevatorOperator.DoorTimer.start(e)
    end

    :keep_state_and_data
  end

  def handle_event(:cast, {:request_button_press, _order}, :moving, _data) do
    :keep_state_and_data
  end

  def handle_event(:cast, {:request_button_press, %Order{} = order}, :idle, %Elevator{} = e) do
    if e.floor == order.floor do
      OrderDistributor.distribute_completed(order)
      Driver.set_door_open_light(:on)
      ElevatorOperator.DoorTimer.start(e)
      {:next_state, :door_open, e}
    else
      direction = choose_direction(e)
      Driver.set_motor_direction(direction)
      {:next_state, :moving, %{e | direction: direction}}
    end
  end

  # Floor arrival callbacks -----------------------------
  def handle_event(:cast, {:floor_arrival, floor}, :moving, %Elevator{} = e) do
    Driver.set_floor_indicator(floor)

    if should_stop?(%{e | floor: floor}) do
      Driver.set_motor_direction(:stop)
      Driver.set_door_open_light(:on)
      OrderDistributor.distribute_completed(own_orders(floor))
      ElevatorOperator.DoorTimer.start(e)
      {:next_state, :door_open, %{e | floor: floor, direction: :stop}}
    else
      {:keep_state, %{e | floor: floor}}
    end
  end

  def handle_event(:cast, {:floor_arrival, floor}, _state, %Elevator{} = e) do
    Driver.set_floor_indicator(floor)
    {:keep_state, %{e | floor: floor}}
  end

  # Door timeout callbacks ------------------------------
  def handle_event(:info, :door_timeout, :door_open, %Elevator{} = e) do
    Driver.set_door_open_light(:off)
    direction = choose_direction(e)
    Driver.set_motor_direction(direction)

    case direction do
      :stop -> {:next_state, :idle, %{e | direction: direction, timer_ref: nil}}
      _ -> {:next_state, :moving, %{e | direction: direction, timer_ref: nil}}
    end
  end

  def handle_event(:info, :door_timeout, _state, _data) do
    :keep_state_and_data
  end

  # Obstruction switch callbacks ------------------------
  def handle_event(:cast, {:obstruction_sensor_update, is_obstructed}, :door_open, %Elevator{} = e) do
    updated_e = %{e | is_obstructed: is_obstructed}

    if is_obstructed do
      ElevatorOperator.DoorTimer.stop(updated_e)
    else
      ElevatorOperator.DoorTimer.start(updated_e)
    end

    {:keep_state, updated_e}
  end

  def handle_event(:cast, {:obstruction_sensor_update, is_obstructed}, _state, %Elevator{} = e) do
    {:keep_state, %{e | is_obstructed: is_obstructed}}
  end

  # Timer callbacks -------------------------------------
  def handle_event(:cast, {:timer_update, timer_ref}, _state, %Elevator{} = e) do
    {:keep_state, %{e | timer_ref: timer_ref}}
  end

  # Data retrieval callbacks ----------------------------
  def handle_event({:call, from}, :get_data, state, %Elevator{} = e) do
    data = {
      e.floor,
      e.direction,
      state,
      own_orders()
    }

    {:keep_state_and_data, [{:reply, from, data}]}
  end

  # Helper functions ------------------------------------
  defp own_orders() do
    Enum.filter(
      Orders.get(),
      fn %Order{} = order -> order.owner == Node.self() end
    )
  end

  defp own_orders(floor) do
    Enum.filter(
      Orders.get(),
      fn %Order{} = order -> order.owner == Node.self() and order.floor == floor end
    )
  end

  defp choose_direction(%Elevator{} = e) do
    case e.direction do
      :up ->
        cond do
          orders_above?(e) -> :up
          orders_below?(e) -> :down
          true -> :stop
        end

      _ ->
        cond do
          orders_below?(e) -> :down
          orders_above?(e) -> :up
          true -> :stop
        end
    end
  end

  defp should_stop?(%Elevator{} = e) do
    case e.direction do
      :up ->
        relevant_orders =
          Enum.filter(
            own_orders(e.floor),
            fn %Order{} = order -> order.button_type in [:cab, :hall_up] end
          )

        not orders_above?(e) or not Enum.empty?(relevant_orders)

      :down ->
        relevant_orders =
          Enum.filter(
            own_orders(e.floor),
            fn %Order{} = order -> order.button_type in [:cab, :hall_down] end
          )

        not orders_below?(e) or not Enum.empty?(relevant_orders)

      _ ->
        true
    end
  end

  defp orders_above?(%Elevator{} = e) do
    own_orders()
    |> Enum.filter(fn %Order{} = order -> order.floor > e.floor end)
    |> Enum.any?()
  end

  defp orders_below?(%Elevator{} = e) do
    own_orders()
    |> Enum.filter(fn %Order{} = order -> order.floor < e.floor end)
    |> Enum.any?()
  end
end

defmodule ElevatorOperator.DoorTimer do
   @moduledoc """
  Finite state machine responible for running one elevator, implemented using the behaviour GenStateMachine.
  The state machine has the states `idle`, `moving` and `door_open`, and keeps track of the current floor,
  moving direction, obstructed sensor state and door timer.

  Uses the following modules:
  - `ElevatorOperator`
  """

  alias ElevatorOperator, as: Elevator

  @door_timer_duration 2_000

  @doc """
  Starts the door timer if the elevator is not obstructed. Calls `ElevatorOperator.timer_update/1`
  to update the timer reference to the newly set timer.
  ## Parameters
  - e: Struct containing the current state of the elevator :: %ElevatorOperator{}
  """
  def start(%Elevator{is_obstructed: false} = e) do
    if e.timer_ref do
      Process.cancel_timer(e.timer_ref)
    end
    timer_ref = Process.send_after(self(), :door_timeout, @door_timer_duration)
    Elevator.timer_update(timer_ref)
  end

  def start(%Elevator{is_obstructed: true}) do
  end

  @doc """
  Stops the door timer if it is active. Calls `ElevatorOperator.timer_update/1`
  to update the timer reference to `nil`.
  ## Parameters
  - e: Struct containing the current state of the elevator :: %ElevatorOperator{}
  """
  def stop(%Elevator{} = e) do
    if e.timer_ref do
      Process.cancel_timer(e.timer_ref)
      Elevator.timer_update(nil)
    end
  end
end
