defmodule Persist.ProducerRegistryTest do
  use ExUnit.Case, async: true

  alias Persist.ProducerRegistry

  setup ctx do
    opts = [starter: self(), whereis_timeout: ctx[:whereis_timeout] || 0]
    {:ok, _} = ProducerRegistry.start_link(__MODULE__, opts)
    :ok
  end

  test "register_name/2" do
    assert :yes   == ProducerRegistry.register_name({__MODULE__, :foo}, self())
    assert :no    == ProducerRegistry.register_name({__MODULE__, :foo}, self())
    assert self() == ProducerRegistry.whereis_name({__MODULE__, :foo})
  end

  test "unregister_name/2" do
    assert :yes == ProducerRegistry.register_name({__MODULE__, :foo}, self())
    assert :yes == ProducerRegistry.unregister_name({__MODULE__, :foo})
    assert :undefined == ProducerRegistry.whereis_name({__MODULE__, :foo})
  end

  test "removes registration when process dies" do
    pid = start_mock()
    assert :yes == ProducerRegistry.register_name({__MODULE__, :foo}, pid)
    stop_mock(pid)
    assert :undefined == ProducerRegistry.whereis_name({__MODULE__, :foo})
  end

  test "send/2" do
    name = {__MODULE__, :foo}
    assert {:badarg, {name, :hello}} == catch_exit(ProducerRegistry.send(name, :hello))
    assert :yes = ProducerRegistry.register_name(name, self())
    ProducerRegistry.send(name, :hello)
    assert_received :hello
  end

  @tag whereis_timeout: 100
  test "whereis_name/1 attempts to start process" do
    name = {__MODULE__, :foo}
    task = Task.async(fn -> ProducerRegistry.whereis_name(name) end)
    assert_receive {:"$gen_cast", {:start_producer, :foo}}
    ProducerRegistry.register_name(name, self())
    assert self() == Task.await(task)
  end

  defp start_mock do
    spawn_link(fn ->
      receive do
        :stop -> :ok
      end
    end)
  end

  defp stop_mock(pid) do
    ref = Process.monitor(pid)
    send(pid, :stop)
    assert_receive {:DOWN, ^ref, _, ^pid, _}
  end
end
