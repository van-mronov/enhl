defmodule ENHL.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      worker(ENHL.Registry, []),
      supervisor(ENHL.Report.Supervisor, [])
    ]

    supervise(children, strategy: :rest_for_one)
  end
end
