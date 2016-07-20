alias Experimental.{GenStage}

defmodule Persist.Consumer do
  use GenStage

  def init({_meta, _data} = state) do
    {:consumer, state}
  end

  def handle_events(events, _from, {meta, data} = state) do
    count  = Enum.count(events)
    max_id = Persist.Storage.update_counter(meta, :total_events, count)
    {objects, ^max_id} =
      Enum.map_reduce(events, max_id - count, &{{&2, &1}, &2 + 1})
    :ok = Persist.Storage.insert(data, objects)
    {:noreply, [], state}
  end
end
