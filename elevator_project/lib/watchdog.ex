defmodule Watchdog do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  # API -------------------------------------------------
  def start(%Order{} = order) do
    GenServer.cast(__MODULE__, {:start_timer, order})
  end

  def stop(%Order{} = order) do
    GenServer.cast(__MODULE__, {:stop_timer, order})
  end

   # Init ------------------------------------------------
   @impl true
   def init(_args) do
     {:ok, []}
   end

   # Casts -----------------------------------------------
   def handle_cast({:start_timer, %Order{} = order}, active_timers) do

   end

   def handle_cast({:stop_timer, %Order{} = order}, active_timers) do

   end

   def handle_info({:expired_order, %Order{} = order}, active_timers) do

   end

   # Helper functions ------------------------------------

end
