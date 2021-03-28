defmodule Test do
  def merge do
    order_backup1 = [ %Order{button_type: :cab, floor: 2},
                      %Order{button_type: :hall_down, floor: 2},
                      %Order{button_type: :cab, floor: 3}]
    order_backup2 = [ %Order{button_type: :cab, floor: 1},
                      %Order{button_type: :hall_down, floor: 2},
                      %Order{button_type: :cab, floor: 4}]
    order_backup3 = [ %Order{button_type: :hall_up, floor: 2},
                      %Order{button_type: :hall_down, floor: 2},
                      %Order{button_type: :cab, floor: 3}]
    OrderBackup.merge([order_backup1, order_backup2, order_backup3])
    OrderBackup.get()
  end

  def remove_order() do

  end

  def order_assigner_broadcast() do
    _example_order = %Order{button_type: :hall_up, floor: 1, watchdog_ref: nil}
    Network.Init.start_node("henrik")
    OrderAssigner.start_link()
    Elevator.Orders.start_link()
    Elevator.Orders.new(:hall_up, 2)
    order = %Order{button_type: :hall_up, floor: 1, watchdog_ref: nil}
    OrderAssigner.assign_order(order)
  end
end
