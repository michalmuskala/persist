defmodule Persist.ProducerRegistry do
  use GenServer

  alias Persist.ProducerStarter

  def start_link(name, opts) do
    GenServer.start_link(__MODULE__, {name, opts}, name: name)
  end

  ## required :via interface

  def register_name({manager, sub}, pid) do
    GenServer.call(manager, {:register, sub, pid})
  end

  def unregister_name({manager, sub}) do
    GenServer.call(manager, {:unregister, sub})
  end

  def whereis_name({manager, sub}) do
    GenServer.call(manager, {:whereis, sub}, :infinity)
  end

  def send(name, message) do
    case whereis_name(name) do
      pid when is_pid(pid) -> Kernel.send(pid, message)
      :undefined           -> exit({:badarg, {name, message}})
    end
  end

  ## Other public functions

  def list(manager) do
    GenServer.call(manager, :list)
  end

  ## Implementation

  def init({name, opts}) do
    {:ok, %{name: name, subs: %{}, refs: %{}, waiting: %{},
            whereis_timeout: Keyword.get(opts, :whereis_timeout, 5_000),
            starter: Keyword.fetch!(opts, :starter)}}
  end

  def handle_call({:register, sub, pid}, _from, state) do
    if Map.has_key?(state.subs, sub) do
      {:reply, :no, state}
    else
      {:reply, :yes, register_sub(sub, pid, state)}
    end
  end

  def handle_call({:unregister, sub}, _from, state) do
    {:reply, :yes, update_in(state.subs, &Map.delete(&1, sub))}
  end

  def handle_call({:whereis, sub}, from, state) do
    case Map.fetch(state.subs, sub) do
      {:ok, pid} ->
        {:reply, pid, state}
      :error ->
        ref = :erlang.start_timer(state.whereis_timeout, self(), sub)
        waiting = Map.update(state.waiting, sub, [{ref, from}], &[{ref, from} | &1])
        ProducerStarter.start_producer(state.starter, sub)
        {:noreply, %{state | waiting: waiting}}
    end
  end

  def handle_call(:list, _from, state) do
    {:reply, Map.values(state.subs), state}
  end

  defp register_sub(sub, pid, state) do
    ref     = Process.monitor(pid)
    subs    = Map.put(state.subs, sub, pid)
    refs    = Map.put(state.refs, ref, sub)
    waiting = dispatch_waiting(sub, pid, state.waiting)
    %{state | subs: subs, refs: refs, waiting: waiting}
  end

  defp dispatch_waiting(sub, pid, waiting) do
    {requests, waiting} = Map.pop(waiting, sub, [])
    Enum.each(requests, fn {timer_ref, from} ->
      :erlang.cancel_timer(timer_ref)
      GenServer.reply(from, pid)
    end)
    waiting
  end

  def handle_info({:timeout, ref, sub}, %{waiting: waiting} = state) do
    requests = Map.get(waiting, sub, [])
    requests =
      case List.keytake(requests, ref, 0) do
        {{^ref, from}, rest} ->
          GenServer.reply(from, :undefined)
          rest
        nil ->
          requests
      end
    {:noreply, put_in(state.waiting[sub], requests)}
  end

  def handle_info({:DOWN, ref, _, pid, _}, %{subs: subs, refs: refs} = state) do
    with {sub, rest_refs}  <- Map.pop(refs, ref),
         {^pid, rest_subs} <- Map.pop(subs, sub) do
      {:noreply, %{state | refs: rest_refs, subs: rest_subs}}
    else
      _ ->
        {:stop, {:unknown_sub, ref, pid}, state}
    end
  end
end
