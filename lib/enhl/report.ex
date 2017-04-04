defmodule ENHL.Report do
  use GenServer

  @doc """
  Starts a new report.
  """
  def start_link(year, game_id) do
    GenServer.start_link(__MODULE__, year: year, game_id: game_id)
  end

  @doc """
  Returns the year of the `report`.

  Returns `{:ok, year}`.
  """
  def year(report) do
    GenServer.call(report, :year)
  end

  @doc """
  Returns the game_id of the `report`.

  Returns `{:ok, game_id}`.
  """
  def game_id(report) do
    GenServer.call(report, :game_id)
  end

  ## Server Callbacks

  def init(year: year, game_id: game_id) do
    {:ok, {year, game_id}}
  end

  def handle_call(:year, _from, {year, _game_id} = state) do
    {:reply, {:ok, year}, state}
  end

  def handle_call(:game_id, _from, {_year, game_id} = state) do
    {:reply, {:ok, game_id}, state}
  end
end
