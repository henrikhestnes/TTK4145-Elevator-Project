defmodule ObstructionPoller do
  @poller_sleep_ms 100

  use Task

  def start_link do
    Task.start_link(__MODULE__, :poller, [:inactive])
  end

  def poller(prev_state) do
    current_state = Driver.get_obstruction_switch_state()
    case {prev_state, current_state} do
      {:inactive, :active} -> Elevator.obstruction(true)
      {:active, :inactive} -> Elevator.obstruction(false)
      _ -> :ok
    end

    Process.sleep(@poller_sleep_ms)
    poller(current_state)
  end
end

defmodule FloorPoller do
  @poller_sleep_ms 100

  use Task

  def start_link do
    Task.start_link(__MODULE__, :poller, [:between_floors])
  end

  def poller(prev_state) do
    current_state = Driver.get_floor_sensor_state()
    # case {prev_state, current_state} do
    #   {:between_floors, floor} when floor != :between_floors ->
    #     Elevator.floor_arrival(floor)
    #   _ -> :ok
    # end

    if current_state != :between_floors and prev_state == :between_floors do
      Elevator.floor_arrival(current_state)
    end

    Process.sleep(@poller_sleep_ms)
    poller(current_state)
  end
end

defmodule OrderButtonPoller do
  @poller_sleep_ms 100

  use Task

  def start_link(floor, button_type) do
    Task.start_link(__MODULE__, :poller, [floor, button_type, :released])
  end

  def poller(floor, button_type, prev_state) do
    current_state = Driver.get_order_button_state(floor, button_type)
    if current_state and not prev_state do
      OrderAssigner.assign_order(Order.new(button_type, floor))
    end

    Process.sleep(@poller_sleep_ms)
    poller(floor, button_type, current_state)
  end
end
