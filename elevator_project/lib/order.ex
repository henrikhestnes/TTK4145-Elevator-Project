defmodule Order do
  @valid_orders [:cab, :hall_down, :hall_up]
  @enforce_keys [:button_type, :floor]
  defstruct [:button_type, :floor]

  def new(button_type, floor) when button_type in @valid_orders and is_integer(floor) do
    %Order{
      button_type: button_type,
      floor: floor
    }
  end

  def all_orders(number_of_floors) do
    upper_floor = number_of_floors - 1
    @valid_orders
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
