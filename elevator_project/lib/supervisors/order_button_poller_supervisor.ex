defmodule OrderButtonPoller.Supervisor do
  use Supervisor

  @button_types [:cab, :hall_up, :hall_down]

  def start_link(number_of_floors) do
    Supervisor.start_link(__MODULE__, number_of_floors, name: __MODULE__)
  end

  @impl true
  def init(number_of_floors) do
    all_buttons = all_buttons(number_of_floors)

    Enum.each(
      all_buttons,
      fn button -> Driver.set_order_button_light(button.type, button.floor, :off) end
    )

    children = Enum.map(
      all_buttons, fn button -> Supervisor.child_spec(
        OrderButtonPoller,
        start: {OrderButtonPoller, :start_link, [button.floor, button.type]},
        id: {OrderButtonPoller, button.floor, button.type},
        restart: :permanent
      ) end
    )

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
      |> Enum.map(fn floor -> %{floor: floor, type: type} end)
    end)
    |> List.flatten()
  end
end
