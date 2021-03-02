defmodule Elevator do
  use GenStateMachine

  @n_floors 4

  @enforce_keys [:floor, :direction]
  defstruct [:floor, :direction]

  def start_link(args \\ []) do
    GenStateMachine.start_link(__MODULE__, {:init, args}, name: __MODULE__)
  end

  # API
  def request_button_press(floor, button_type) do
    GenStateMachine.cast(__MODULE__, {:request_button_press, floor, button_type})
  end

  def floor_arrival(floor) do
    GenStateMachine.cast(__MODULE__, {:floor_arrival, floor})
  end

  def door_timeout() do
    GenStateMachine.cast(__MODULE__, :door_timeout)
  end

  # Initialization and termination callbacks
  def init({:init, _}) do
    Orders.start_link()
    Driver.set_door_open_light(:off)
    Driver.set_motor_direction(:down)

    e = %Elevator{
      floor: nil,
      direction: :down
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
      # restart door timer
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
      # start door timer
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
      # start door timer
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
  def handle_event(:cast, :door_timeout, :door_open, %Elevator{} = e) do
    Driver.set_door_open_light(:off)
    direction = Orders.choose_direction(e)
    Driver.set_motor_direction(direction)
    case direction do
      :stop -> {:next_state, :idle, %{e | direction: direction}}
      _ -> {:next_state, :moving, %{e | direction: direction}}
    end
  end

  def handle_event(:cast, :door_timeout, _state, _data) do
    :keep_state_and_data
  end

  # Helper functions
  def handle_event(:cast, :print, state, %Elevator{} = e) do
    IO.puts("State: #{state}")
    IO.puts("Floor: #{e.floor}")
    IO.puts("Direction: #{e.direction}")
    :keep_state_and_data
  end

  def print() do
    GenStateMachine.cast(__MODULE__, :print)
  end

end
