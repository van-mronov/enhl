defmodule ENHL do
  use Application

  def start(_type, _args) do
    ENHL.Supervisor.start_link
  end
end
