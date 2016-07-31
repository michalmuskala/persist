alias Experimental.{GenStage}

defmodule Persist.Consumer do
  use GenStage

  def start_link(name, persist_opts, opts \\ []) do
    GenStage.start_link(__MODULE__, {name, persist_opts}, opts)
  end

  def save_events(consumer, events) do
    GenStage.cast(consumer, {:save_events, events})
  end

  def init({name, opts}) do
    state = %{name: name,
              meta: {name, :meta},
              data: {name, :data},
              temp: {name, :temp},
              registry: opts[:registry]}
    {:consumer, init_tables(state)}
  end

  def handle_events(events, _from, state) do
    {:noreply, [], do_save_events(events, state)}
  end

  def handle_cast({:save_events, events}, state) do
    {:noreply, [], do_save_events(events, state)}
  end

  defp do_save_events(events, state) do
    count  = Enum.count(events)
    max_id = :dets.update_counter(state.meta, :last_saved, count)
    {objects, ^max_id} =
      Enum.map_reduce(events, max_id - count, &{{&2, &1}, &2 + 1})
    :ok = :dets.insert(state.data, objects)
    notify_producers(count, state)
    state
  end

  defp notify_producers(count, state) do
    for producer <- Persist.ProducerRegistry.list(state.registry) do
      Persist.Producer.notify(producer, count)
    end
  end

  defp init_tables(state) do
    :dets.insert_new(state.meta, {:last_saved, 0})
    state
  end
end
