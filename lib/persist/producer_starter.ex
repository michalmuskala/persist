defmodule Persist.ProducerStarter do
  use GenServer

  def start_link(name, persist_opts, opts \\ []) do
    GenServer.start_link(__MODULE__, {name, persist_opts}, opts)
  end

  def start_producer(starter, sub) do
    GenServer.cast(starter, {:start_producer, sub})
  end

  def init({_name, opts}) do
    {:ok, %{supervisor: Keyword.fetch!(opts, :supervisor)}}
  end

  def handle_cast({:start_producer, sub}, %{supervisor: supervisor} = state) do
    {:ok, _} = Persist.ProducerWorkerSupervisor.start_producer(supervisor, sub)
    {:noreply, state}
  end
end
