defmodule Persist.ProducerSupervisor do
  import Supervisor.Spec

  def start_link(name, opts, supervisor_opts \\ []) do
    children = [
      worker(Persist.ProducerRegistry, [name, opts, [name: opts[:registry]]]),
      worker(Persist.ProducerStarter, [name, opts, [name: opts[:starter]]]),
      supervisor(Persist.ProducerWorkerSupervisor, [name, opts, [name: opts[:supervisor]]])
    ]

    supervisor_opts = Keyword.put(supervisor_opts, :strategy, :rest_for_one)

    Supervisor.start_link(children, supervisor_opts)
  end
end
