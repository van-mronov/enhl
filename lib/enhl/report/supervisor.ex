defmodule ENHL.Report.Supervisor do
  use Supervisor

  # A simple module attribute that stores the supervisor name
  @name ENHL.Report.Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @name)
  end

  def start_report(year, game_id) do
    Supervisor.start_child(@name, [year, game_id])
  end

  def init(:ok) do
    children = [
      worker(ENHL.Report, [], restart: :temporary)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end
end
