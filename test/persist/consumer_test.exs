alias Experimental.{GenStage}

defmodule Persist.ConsumerTest do
  use ExUnit.Case, async: true

  import Persist.FileHelpers

  alias Persist.Consumer

  setup do
    in_tmp fn path ->
      {:ok, _} = :dets.open_file({__MODULE__, :data}, [type: :set, file: '#{path}/data.tab'])
      {:ok, _} = :dets.open_file({__MODULE__, :meta}, [type: :set, file: '#{path}/meta.tab'])
    end
    test = self()
    registry = spawn_link(fn -> registry_mock(test) end)
    {:ok, consumer} = Consumer.start_link(__MODULE__, registry: registry)
    {:ok, consumer: consumer, registry: registry}
  end

  test "saves events passed explicitly", %{consumer: consumer} do
    Consumer.save_events(consumer, [:foo, :bar])
    assert_receive {:"$gen_cast", {:notify, 2}}
    assert [[{1, :bar}], [{0, :foo}]] == :dets.match({__MODULE__, :data}, :"$1")
    assert [{:last_saved, 2}] == :dets.lookup({__MODULE__, :meta}, :last_saved)

    Consumer.save_events(consumer, [:baz])
    assert_receive {:"$gen_cast", {:notify, 1}}
    assert [[{1, :bar}], [{0, :foo}], [{2, :baz}]] == :dets.match({__MODULE__, :data}, :"$1")
    assert [{:last_saved, 3}] == :dets.lookup({__MODULE__, :meta}, :last_saved)
  end

  test "saves events passed via GenStage", %{consumer: consumer} do
    {:ok, producer} = GenStage.from_enumerable([:foo, :bar])
    GenStage.sync_subscribe(consumer, to: producer)
    assert_receive {:"$gen_cast", {:notify, 2}}
    assert [[{1, :bar}], [{0, :foo}]] == :dets.match({__MODULE__, :data}, :"$1")
    assert [{:last_saved, 2}] == :dets.lookup({__MODULE__, :meta}, :last_saved)

    {:ok, producer} = GenStage.from_enumerable([:baz])
    GenStage.sync_subscribe(consumer, to: producer)
    assert_receive {:"$gen_cast", {:notify, 1}}
    assert [[{1, :bar}], [{0, :foo}], [{2, :baz}]] == :dets.match({__MODULE__, :data}, :"$1")
    assert [{:last_saved, 3}] == :dets.lookup({__MODULE__, :meta}, :last_saved)
  end

  defp registry_mock(pid) do
    receive do
      {:"$gen_call", from, :list} ->
        GenServer.reply(from, [pid])
        registry_mock(pid)
    end
  end
end
