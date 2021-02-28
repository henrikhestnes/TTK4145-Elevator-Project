defmodule Elevator do
  use GenServer

  @n_floors 4

  defstruct [:floor, :direction, :fsm_state]

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  # API


  # Casts

  # Calls

end
