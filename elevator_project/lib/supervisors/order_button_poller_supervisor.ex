defmodule OrderButtonPoller.Supervisor do
  use Supervisor

  def start_link(number_of_floors) do
    Supervisor.start_link(__MODULE__, number_of_floors, name: __MODULE__)
  end

  @impl true
  def init(number_of_floors) do
    all_buttons = Orders.all_orders(number_of_floors)

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
end
