defmodule OrderButtonPoller.Supervisor do
  use Supervisor

  def start_link(number_of_floors) do
    Supervisor.start_link(__MODULE__, number_of_floors, name: __MODULE__)
  end

  @impl true
  def init(number_of_floors) do
    all_orders = Order.all_orders(number_of_floors)

    Enum.each(
      all_orders,
      fn order -> Driver.set_order_button_light(order.button_type, order.floor, :off) end
    )

    children = Enum.map(
      all_orders, fn order -> Supervisor.child_spec(
        OrderButtonPoller,
        start: {OrderButtonPoller, :start_link, [order.floor, order.button_type]},
        id: {OrderButtonPoller, order.floor, order.button_type},
        restart: :permanent
      ) end
    )

    Supervisor.init(children, strategy: :one_for_one)
  end
end
