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
    opts = [supervisor: Module.concat(name, Supervisor),
            registry:   Module.concat(name, Registry),
            starter:    Module.concat(name, Starter),
            consumer:   Module.concat(name, Consumer)] ++ opts

    supervisor(__MODULE__, [name, opts])
  end

  def start_link(name, opts) do
    children = [
      worker(Persist.TableOwner, [name, opts]),
      worker(Persist.Consumer, [name, opts, name: opts[:consumer]]),
      supervisor(Persist.ProducerSupervisor, [name, opts])
    ]

    Supervisor.start_link(children, strategy: :rest_for_all)
  end
end
