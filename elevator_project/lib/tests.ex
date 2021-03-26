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
    OrderBackup.get_orders
  end

  def remove_order() do
    
  end
end

