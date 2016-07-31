defmodule Persist.ProducerSupervisor do
  import Supervisor.Spec

  def start_link(name, start_args, opts) do
    children = [
      worker(Persist.Producer, start_args)
    ]

    opts = Keyword.put(opts, :strategy, :simple_one_for_one)

    Supervisor.start_link(children, opts)
  end

  def start_producer(supervisor, subscription) do
    Supervisor.start_child(supervisor, [subscription])
  end
end
