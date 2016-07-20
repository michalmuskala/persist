defmodule Persist.Storage do
  @type object :: {id :: integer, term}

  @callback init(opts :: [term]) :: state :: term

  @callback insert(state :: term, [object]) :: :ok

  @callback lookup(state :: term, initial_id :: integer, count :: integer) :: [object]

  @callback lookup_counter(state :: term, key :: term) :: integer

  @callback update_counter(state :: term, key :: term, incr :: integer) :: integer

  def init(opts) do
    adapter = Keyword.fetch!(opts, :adapter)
    state   = adapter.init(opts)
    {adapter, state}
  end

  def insert({adapter, state}, objects) do
    adapter.insert(state, objects)
  end

  def lookup({adapter, state}, initial_id, count) do
    adapter.lookup(state, initial_id, count)
  end

  def lookup_counter({adapter, state}, key) do
    adapter.lookup_counter(state, key)
  end

  def update_counter({adapter, state}, key, incr) do
    adapter.update_counter(state, key, incr)
  end
end
