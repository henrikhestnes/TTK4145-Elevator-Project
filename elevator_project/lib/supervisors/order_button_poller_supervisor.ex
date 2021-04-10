defmodule OrderButtonPoller.Supervisor do
  use Supervisor

  @button_types [:cab, :hall_up, :hall_down]

  def start_link(number_of_floors) do
    Supervisor.start_link(__MODULE__, number_of_floors, name: __MODULE__)
  end

  @impl true
  def init(number_of_floors) do
    all_buttons = all_buttons(number_of_floors)

    children = Enum.map(
      all_buttons, fn button -> Supervisor.child_spec(
        {OrderButtonPoller, [button.floor, button.button_type]},
        id: {OrderButtonPoller, button.floor, button.button_type},
        restart: :permanent
      )
      end
    )

    Enum.each(all_buttons, fn button -> Driver.set_order_button_light(button.floor, :off) end)

    Supervisor.init(children, strategy: :one_for_one)
  end

  def all_buttons(number_of_floors) do
    upper_floor = number_of_floors - 1
    @button_types 
    |> Enum.map(fn type -> 
      case type do
        :cab        -> 0..upper_floor
        :hall_down  -> 1..upper_floor
        :hall_up    -> 0..(upper_floor - 1)
      end
      |> Enum.map(fn floor -> %{floor: floor, button_type: type} end) 
      end) 
    |> List.flatten()
  end
end
