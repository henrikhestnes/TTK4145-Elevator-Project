defmodule Elevator do
  use GenStateMachine
  alias Elevator.Timer

  @n_floors 4

  @enforce_keys [:floor, :direction, :timer_ref]
  defstruct [:floor, :direction, :timer_ref]

  def start_link(args \\ []) do
    GenStateMachine.start_link(__MODULE__, {:init, args}, name: __MODULE__)
  end

  # API --------------------------------------------------------------------------
  def request_button_press(floor, button_type) do
    GenStateMachine.cast(__MODULE__, {:request_button_press, floor, button_type})
  end

  def floor_arrival(floor) do
    GenStateMachine.cast(__MODULE__, {:floor_arrival, floor})
  end

  def obstruction(is_obstructed) do
    GenStateMachine.cast(__MODULE__, {:obstruction, is_obstructed})
  end

  # Initialization and termination callbacks -------------------------------------
  def init({:init, _}) do
    Orders.start_link()

    # case Driver.get_floor_sensor_state() do
    #   :between_floors ->
    #     Driver.set_door_open_light(:off)
    #     Driver.set_motor_direction(:down)

    #     e = %Elevator{
    #       floor: nil,
    #       direction: :down,
    #       timer_ref: nil
    #     }
    #     {:ok, :moving, e}
    #   floor ->
    #     e = %Elevator{
    #       floor: floor,
    #       direction: :stop,
    #       timer_ref: nil
    #     }
    #     {:ok, :idle, e}
    # end

    e = %Elevator{
            floor: nil,
            direction: :down,
            timer_ref: nil
          }
    {:ok, :moving, e}
  end

  def terminate(_reason, _state, _data) do
    Driver.set_motor_direction(:stop)
  end

  # Request button press callbacks
  # TODO: update request lights
  def handle_event(:cast, {:request_button_press, button_floor, button_type}, :door_open, %Elevator{} = e) do
    if e.floor == button_floor do
      Timer.start(e)
    else
      Orders.new(button_type, button_floor)
    end
    :keep_state_and_data
  end

  def handle_event(:cast, {:request_button_press, button_floor, button_type}, :moving, _data) do
    Orders.new(button_type, button_floor)
    :keep_state_and_data
  end

  def handle_event(:cast, {:request_button_press, button_floor, button_type}, :idle, %Elevator{} = e) do
    if e.floor == button_floor do
      Driver.set_door_open_light(:on)
      Timer.start(e)
      {:next_state, :door_open, e}
    else
      Orders.new(button_type, button_floor)
      direction = Orders.choose_direction(e)
      Driver.set_motor_direction(direction)
      {:next_state, :moving, %{e | direction: direction}}
    end
  end

  # Floor arrival callbacks
  def handle_event(:cast, {:floor_arrival, floor}, :moving, %Elevator{} = e) do
    Driver.set_floor_indicator(floor)

    if Orders.should_stop?(e) do
      Driver.set_motor_direction(:stop)
      Driver.set_door_open_light(:on)
      Orders.clear_at_floor(floor)
      Timer.start(e)
      # update lights
      {:next_state, :door_open, %{e | floor: floor, direction: :stop}}
    else
      {:keep_state, %{e | floor: floor}}
    end
  end

  def handle_event(:cast, {:floor_arrival, floor}, _state, %Elevator{} = e) do
    Driver.set_floor_indicator(floor)
    {:keep_state, %{e | floor: floor}}
  end

  # Door timeout callbacks
  def handle_event(:info, :door_timeout, :door_open, %Elevator{} = e) do
    Driver.set_door_open_light(:off)
    direction = Orders.choose_direction(e)
    Driver.set_motor_direction(direction)
    case direction do
      :stop -> {:next_state, :idle, %{e | direction: direction}}
      _     -> {:next_state, :moving, %{e | direction: direction}}
    end
  end

  def handle_event(:cast, :door_timeout, _state, _data) do
    :keep_state_and_data
  end

  # Obstruction switch callbacks
  def handle_event(:cast, {:obstruction, is_obstructed}, :door_open, %Elevator{} = e) do
    case is_obstructed do
      true  -> Timer.stop(e)
      false -> Timer.start(e)
    end
    :keep_state_and_data
  end

  def handle_event(:cast, {:obstruction, _}, _state, _data) do
    :keep_state_and_data
  end

  # Timer callbacks
  def handle_event(:cast, {:timer_update, timer_ref}, _state, %Elevator{} = e) do
    {:keep_state, %{e | timer_ref: timer_ref}}
  end

  # Helper functions
  def handle_event(:cast, :print, state, %Elevator{} = e) do
    IO.puts("State: #{state}")
    IO.puts("Floor: #{e.floor}")
    IO.puts("Direction: #{e.direction}")
    case e.timer_ref do
      nil -> IO.puts("No active timer ref")
      _   -> IO.puts("Active timer ref")
    end
    :keep_state_and_data
  end

  def timer_update(timer_ref) do
    GenStateMachine.cast(__MODULE__, {:timer_update, timer_ref})
  end

  def print() do
    GenStateMachine.cast(__MODULE__, :print)
  end

end


defmodule Elevator.Timer do
  @door_timer_duration 3_000

  def start(%Elevator{} = e) do
    if e.timer_ref do
      Process.cancel_timer(e.timer_ref)
    end
    timer_ref = Process.send_after(self(), :door_timeout, @door_timer_duration)
    Elevator.timer_update(timer_ref)
  end

  def stop(%Elevator{} = e) do
    Process.cancel_timer(e.timer_ref)
    Elevator.timer_update(nil)
  end
end
