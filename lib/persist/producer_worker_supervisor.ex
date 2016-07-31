defmodule Persist.ProducerWorkerSupervisor do
  import Supervisor.Spec

  def start_link(name, persist_opts, opts \\ []) do
    children = [
      worker(Persist.Producer, [name, persist_opts])
    ]

    opts = Keyword.put(opts, :strategy, :simple_one_for_one)

    Supervisor.start_link(children, opts)
  end

  def start_producer(supervisor, subscription) do
    Supervisor.start_child(supervisor, [subscription])
  end
end
