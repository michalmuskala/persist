defmodule Persist.TableOwner do
  use GenServer

  def start_link(name, persist_opts, opts \\ []) do
    GenServer.start_link(__MODULE__, {name, persist_opts}, opts)
  end

  def init({name, opts}) do
    Process.flag(:trap_exit, true)
    path = Keyword.fetch!(opts, :path)
    {:ok, _} = :dets.open_file({name, :data}, type: :set, file: '#{path}/data.tab')
    {:ok, _} = :dets.open_file({name, :meta}, type: :set, file: '#{path}/meta.tab')
    {:ok, _} = :dets.open_file({name, :temp}, type: :bag, file: '#{path}/temp.tab')
    {:ok, {name, path}}
  end

  def terminate(_, {name, _path}) do
    :ok = :dets.close({name, :data})
    :ok = :dets.close({name, :meta})
    :ok = :dets.close({name, :temp})
    :ok
  end
end
