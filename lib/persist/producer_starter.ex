defmodule Persist.ProducerStarter do
  use GenServer

  def start_link(supervisor, opts \\ []) do
    GenServer.start_link(__MODULE__, supervisor, opts)
  end

  def start_producer(starter, sub) do
    GenServer.cast(starter, {:start_producer, sub})
  end

  def handle_cast({:start_producer, sub}, supervisor) do
    {:ok, _} = Persist.ProducerSupervisor.start_producer(supervisor, sub)
    {:noreply, supervisor}
  end
end
