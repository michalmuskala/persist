defmodule Persist do
  import Supervisor.Spec

  def producer(name, subscription) do
    registry_name = Module.safe_concat(name, Registry)
    {:via, Persist.ProducerRegistry, {registry_name, subscription}}
  end

  def consumer(name) do
    Module.safe_concat(name, Consumer)
  end

  def child_spec(name, opts) do
    opts = [supervisor_name: Module.concat(name, Supervisor),
            registry_name:   Module.concat(name, Registry),
            starter_name:    Module.concat(name, Starter),
            consumer_name:   Module.concat(name, Consumer)] ++ opts

    supervisor(__MODULE__, [name, opts])
  end

  def start_link(name, opts) do
    children = [
      worker(Persist.TableOwner, [name, opts]),
      worker(Persist.ProducerRegistry, [name, opts, name: opts[:registry_name]]),
      supervisor(Persist.ProducerSupervisor, [name, opts, name: opts[:supervisor_name]]),
      worker(Persist.ProducerStarter, [name: opts[:starter_name]])
    ]

    Supervisor.start_link(children, strategy: :rest_for_all)
  end
end
