defmodule Persist.ProducerRegistryTest do
  use ExUnit.Case, async: true

  alias Persist.ProducerRegistry

  setup ctx do
    opts = [starter: self(), whereis_timeout: ctx[:whereis_timeout] || 0]
    {:ok, registry} = ProducerRegistry.start_link(__MODULE__, opts)
    {:ok, registry: registry}
  end

  test "register_name/2", %{registry: registry} do
    assert :yes   == ProducerRegistry.register_name({registry, :foo}, self())
    assert :no    == ProducerRegistry.register_name({registry, :foo}, self())
    assert self() == ProducerRegistry.whereis_name({registry, :foo})
  end

  test "unregister_name/2", %{registry: registry} do
    assert :yes == ProducerRegistry.register_name({registry, :foo}, self())
    assert :yes == ProducerRegistry.unregister_name({registry, :foo})
    assert :undefined == ProducerRegistry.whereis_name({registry, :foo})
  end

  test "removes registration when process dies", %{registry: registry} do
    pid = spawn_link(fn ->
      receive do
        :stop -> :ok
      end
    end)
    assert :yes == ProducerRegistry.register_name({registry, :foo}, pid)
    ref = Process.monitor(pid)
    send(pid, :stop)
    assert_receive {:DOWN, ^ref, _, ^pid, _}
    assert :undefined == ProducerRegistry.whereis_name({registry, :foo})
  end

  test "send/2", %{registry: registry} do
    name = {registry, :foo}
    assert {:badarg, {name, :hello}} == catch_exit(ProducerRegistry.send(name, :hello))
    assert :yes = ProducerRegistry.register_name(name, self())
    ProducerRegistry.send(name, :hello)
    assert_received :hello
  end

  @tag whereis_timeout: 100
  test "whereis_name/1 attempts to start process", %{registry: registry} do
    name = {registry, :foo}
    task = Task.async(fn -> ProducerRegistry.whereis_name(name) end)
    assert_receive {:"$gen_cast", {:start_producer, :foo}}
    ProducerRegistry.register_name(name, self())
    assert self() == Task.await(task)
  end
end
