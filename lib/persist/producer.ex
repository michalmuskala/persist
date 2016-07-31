alias Experimental.{GenStage}

defmodule Persist.Producer do
  use GenStage

  alias Persist.Utils

  def start_link(name, persist_opts, sub, opts \\ []) do
    GenStage.start_link(__MODULE__, {name, persist_opts, sub}, opts)
  end

  def ack(stage, id) do
    GenStage.cast(stage, {:ack, id})
  end

  def notify(stage, count) do
    GenStage.cast(stage, {:notify, count})
  end

  defstruct [:name, :sub, :meta, :data, :temp,
             :last_sent, :last_ack, :temp_acks, :sent_timers,
             :demand,
             :timeout, :max_retries]

  def init({name, opts, sub}) do
    state = %__MODULE__{name: name,
                        sub: sub,
                        meta: {name, :meta},
                        data: {name, :data},
                        temp: {name, :temp},
                        last_sent: 0,
                        last_ack: 0,
                        sent_timers: %{},
                        temp_acks: [],
                        demand: 0,
                        timeout: Keyword.get(opts, :ack_timeout, 5_000),
                        max_retries: Keyword.get(opts, :max_retries, 5)}
    {:producer, init_tables(state)}
  end

  def handle_demand(demand, state) when demand > 0 do
    {events, state} = dispatch_events(state.demand + demand, state)
    {:noreply, events, state}
  end

  def handle_cast({:notify, _}, state) do
    {events, state} = dispatch_events(state.demand, state)
    {:noreply, events, state}
  end

  # TODO: handle acks
  def handle_cast({:ack, _id}, state) do
    {:noreply, [], state}
  end

  defp dispatch_events(demand, state) do
    {events, new_demand} = lookup_events(state, state.demand + demand)
    timers = Map.merge(start_timers(events), state.sent_timers)
    {events, %{state | demand: new_demand, sent_timers: timers}}
  end

  # TODO: handle timeouts
  defp start_timers(_), do: %{}

  defp lookup_events(state, demand) do
    spec = compile_lookup_spec(state.last_sent, state.temp_acks)
    case :dets.select(state.data, spec, demand) do
      {:error, reason} ->
        raise "dets error: #{inspect reason}"
      :"$end_of_table" ->
        {[], demand}
      {events, _continuation} ->
        {Enum.sort(events), demand - length(events)}
    end
  end

  defp compile_lookup_spec(last_sent, temp_acks) do
    temp_spec =
      temp_acks
      |> reject_sent(last_sent)
      |> Enum.map(&reject_ack_spec/1)
    [{{:"$1", :_}, [{:>, :"$1", last_sent} | temp_spec], [:"$_"]}]
  end

  defp reject_ack_spec(beg..ends),
    do: {:andalso, [{:<, :"$1", beg}, {:>, :"$1", ends}]}
  defp reject_ack_spec(elem),
    do: {:"/=", :"$1", elem}

  defp reject_sent([_..ends | rest], sent) when ends <= sent,
    do: reject_sent(rest, sent)
  defp reject_sent([ack | rest], sent) when is_integer(ack) and ack <= sent,
    do: reject_sent(rest, sent)
  defp reject_sent([beg..ends | rest], sent) when beg <= sent and sent < ends,
    do: [(sent + 1)..ends | rest]
  defp reject_sent(rest, _sent),
    do: rest

  defp init_tables(state) do
    last_sent = Utils.lookup_insert(state.meta, {state.sub, :last_sent}, state.last_sent)
    last_ack  = Utils.lookup_insert(state.meta, {state.sub, :last_ack},  state.last_ack)
    temp_acks =
      state.temp
      |> :dets.select([{{state.sub, :"$1"}, [], [:"$1"]}])
      |> Enum.sort
      |> minimise_temp_acks
    %{state | last_sent: last_sent, last_ack: last_ack, temp_acks: temp_acks}
  end

  defp minimise_temp_acks([beg..ends, ack | rest]) when ends + 1 == ack,
    do: minimise_temp_acks([beg..ack | rest])
  defp minimise_temp_acks([_.._ = range | rest]),
    do: [range | minimise_temp_acks(rest)]
  defp minimise_temp_acks([ack1, ack2 | rest]) when ack1 + 1 == ack2,
    do: minimise_temp_acks([ack1..ack2 | rest])
  defp minimise_temp_acks([ack | rest]),
    do: [ack | minimise_temp_acks(rest)]
end
