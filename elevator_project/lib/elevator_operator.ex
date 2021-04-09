defmodule Elevator do
  use GenStateMachine
  alias Elevator.Timer
  alias Elevator.Orders

  @enforce_keys [:floor, :direction, :timer_ref]
  defstruct [:floor, :direction, :timer_ref]

  def start_link(args \\ []) do
    GenStateMachine.start_link(__MODULE__, {:init, args}, name: __MODULE__)
  end

  # API --------------------------------------------------------------------------
  def request_button_press(button_type, floor) do
    GenStateMachine.cast(__MODULE__, {:request_button_press, button_type, floor})
  end

  def floor_arrival(floor) do
    GenStateMachine.cast(__MODULE__, {:floor_arrival, floor})
  end

  def obstruction(is_obstructed) do
    GenStateMachine.cast(__MODULE__, {:obstruction_sensor_update, is_obstructed})
  end

  def get_data do
    GenStateMachine.call(__MODULE__, :get_data)
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
            timer_ref: nil,
          }
    {:ok, :moving, e}
  end

  def terminate(_reason, _state, _data) do
    Driver.set_motor_direction(:stop)
  end

  # Request button press callbacks -----------------------------------------------
  def handle_event(:cast, {:request_button_press, button_type, button_floor}, :door_open, %Elevator{} = e) do
    if e.floor == button_floor do
      Timer.start(e)
    else
      Orders.new(button_type, button_floor)
    end
    :keep_state_and_data
  end

  def handle_event(:cast, {:request_button_press, button_type, button_floor}, :moving, _data) do
    Orders.new(button_type, button_floor)
    :keep_state_and_data
  end

  def handle_event(:cast, {:request_button_press, button_type, button_floor}, :idle, %Elevator{} = e) do
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

  # Floor arrival callbacks ------------------------------------------------------
  def handle_event(:cast, {:floor_arrival, floor}, :moving, %Elevator{} = e) do
    Driver.set_floor_indicator(floor)

    if Orders.should_stop?(e) do
      Driver.set_motor_direction(:stop)
      Driver.set_door_open_light(:on)
      Orders.clear_at_floor(floor)
      OrderDistributor.delete_orders(Orders.at_floor(floor))
      Timer.start(e)
      {:next_state, :door_open, %{e | floor: floor, direction: :stop}}
    else
      {:keep_state, %{e | floor: floor}}
    end
  end

  def handle_event(:cast, {:floor_arrival, floor}, _state, %Elevator{} = e) do
    Driver.set_floor_indicator(floor)
    {:keep_state, %{e | floor: floor}}
  end

  # Door timeout callbacks -------------------------------------------------------
  def handle_event(:info, :door_timeout, :door_open, %Elevator{} = e) do
    Driver.set_door_open_light(:off)
    direction = Orders.choose_direction(e)
    Driver.set_motor_direction(direction)
    case direction do
      :stop -> {:next_state, :idle, %{e | direction: direction, timer_ref: nil}}
      _     -> {:next_state, :moving, %{e | direction: direction, timer_ref: nil}}
    end
  end

  def handle_event(:cast, :door_timeout, _state, _data) do
    :keep_state_and_data
  end

  # Obstruction switch callbacks -------------------------------------------------
  def handle_event(:cast, {:obstruction_sensor_update, is_obstructed}, :door_open, %Elevator{} = e) do
    if is_obstructed do
      Timer.stop(e)
    else
      Timer.start(e)
    end
    :keep_state_and_data
  end

  def handle_event(:cast, {:obstruction_sensor_update, _}, _state, _data) do
    :keep_state_and_data
  end

  # Timer callbacks --------------------------------------------------------------
  def handle_event(:cast, {:timer_update, timer_ref}, _state, %Elevator{} = e) do
    {:keep_state, %{e | timer_ref: timer_ref}}
  end

  # Get orders callbacks ---------------------------------------------------------
  def handle_event({:call, from}, :get_data, state, %Elevator{} = e) do
    data = {
      e.floor,
      e.direction,
      state,
      Orders.get()
    }
    {:keep_state_and_data, [{:reply, from, data}]}
  end

  # Helper functions -------------------------------------------------------------
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


defmodule Elevator.Orders do
  use Agent
  @valid_orders [:cab, :hall_down, :hall_up]

  # API --------------------------------------------------------------------------
  def start_link do
    Agent.start_link(fn -> %{:cab => [], :hall_down => [], :hall_up => []} end, name: __MODULE__)
  end

  def new(button_type, floor) when is_integer(floor) and button_type in @valid_orders do
    Agent.update(__MODULE__, fn map -> Map.update(map, button_type, [], fn list -> Enum.uniq([floor | list]) end) end)
  end

  def delete(button_type, floor) when is_integer(floor) and button_type in @valid_orders do
    Agent.update(__MODULE__, fn map -> Map.update(map, button_type, [], fn list -> List.delete(list, floor) end) end)
  end

  def get() do
    Agent.get(__MODULE__, fn orders -> orders end)
  end

  def choose_direction(%Elevator{} = e) do
    case e.direction do
      :up ->
        cond do
          orders_above?(e) -> :up
          orders_below?(e) -> :down
          true -> :stop
        end

      _->
        cond do
          orders_below?(e) -> :down
          orders_above?(e) -> :up
          true -> :stop
        end
    end
  end

  def should_stop?(%Elevator{} = e) do
    case e.direction do
      :up ->
        e.floor in Map.get(orders(), :cab) or
        e.floor in Map.get(orders(), :hall_up) or
        !orders_above?(e)
      :down ->
        e.floor in Map.get(orders(), :cab) or
        e.floor in Map.get(orders(), :hall_down) or
        !orders_below?(e)
      _->
        true
    end
  end

  def clear_at_floor(floor) do
    orders()
    |> Map.keys()
    |> Enum.each(fn button_type -> delete(button_type, floor) end)
  end

  def at_floor(floor) do
    orders()
    |> Enum.filter(fn {_button_type, floors} -> floor in floors end)
    |> Enum.map(fn {button_type, _floors} -> Order.new(button_type, floor) end)
  end

  # Private helper functions -----------------------------------------------------
  defp orders() do
    Agent.get(__MODULE__, fn orders -> orders end)
  end

  defp orders_above?(%Elevator{} = e) do
    orders()
    |> Map.values()
    |> List.flatten()
    |> Enum.filter(fn v -> v > e.floor end)
    |> Enum.any?
  end

  defp orders_below?(%Elevator{} = e) do
    orders()
    |> Map.values()
    |> List.flatten()
    |> Enum.filter(fn v -> v < e.floor end)
    |> Enum.any?
  end
end
