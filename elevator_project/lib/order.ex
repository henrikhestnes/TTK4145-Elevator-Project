defmodule Order do
  @valid_orders [:cab, :hall_down, :hall_up]
  @enforce_keys [:button_type, :floor]
  defstruct [:button_type, :floor, :watchdog_ref]

  def new(button_type, floor) when button_type in @valid_orders and is_integer(floor) do
    %Order{
      button_type: button_type,
      floor: floor,
      watchdog_ref: nil
    }
  end
end
