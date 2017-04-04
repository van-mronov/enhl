defmodule ENHL.Registry do
  use GenServer

  @doc """
  Starts the registry.
  """
  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Returns the report by `year` and `game_id`.

  Returns `{:ok, report}` if the report exists, `:error` otherwise.
  """
  def report(year, game_id) do
    GenServer.call(__MODULE__, {:report, year, game_id})
  end

  @doc """
  Stops the registry.
  """
  def stop do
    GenServer.stop(__MODULE__)
  end

  ## Server Callbacks

  def init(:ok) do
    games = %{}
    refs  = %{}
    {:ok, {games, refs}}
  end

  def handle_call({:report, year, game_id}, _from, {games, refs} = state) do
    key = game_key(year, game_id)

    if Map.has_key?(games, key) do
      {:reply, Map.fetch(games, key), state}
    else
      {:ok, pid} = ENHL.Report.Supervisor.start_report(year, game_id)
      ref = Process.monitor(pid)
      refs = Map.put(refs, ref, key)
      games = Map.put(games, key, pid)
      {:reply, {:ok, pid}, {games, refs}}
    end
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp game_key(year, game_id) do
    :crypto.hash(:sha256, "#{year}#{game_id}") |> Base.encode64
  end
end
