defmodule Order do
  @moduledoc """
  Module defining the form of the order struct, as well as creating orders on the right form.
  The order struct contains information of :button_type and _floor.
  """

  @valid_orders [:cab, :hall_down, :hall_up]
  @enforce_keys [:button_type, :floor]
  defstruct [:button_type, :floor]

  @doc """
  Creating an order struct for an order based on button_type and floor

  ## Parameters
    - button_type: Button type of the order, can be :cab, :hall_up or :hall_down
    - floor: Floor of the order, must be an integer

  ## Return
    - %Order{:button_type, :floor}
  """
  def new(button_type, floor) when button_type in @valid_orders and is_integer(floor) do
    %Order{
      button_type: button_type,
      floor: floor
    }
  end
end
