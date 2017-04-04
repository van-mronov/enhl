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

  @doc """
  Fetches the report from NHL site.

  Returns `:ok` if the report fetched successfully, `:error` otherwise.
  """
  def fetch(report) do
    GenServer.call(report, :fetch)
  end

  ## Server Callbacks

  def init(year: year, game_id: game_id) do
    {:ok, {year, game_id, nil}}
  end

  def handle_call(:year, _from, {year, _game_id, _file} = state) do
    {:reply, {:ok, year}, state}
  end

  def handle_call(:game_id, _from, {_year, game_id, _file} = state) do
    {:reply, {:ok, game_id}, state}
  end

  def handle_call(:fetch, _from, {year, game_id, file} = state) do
    if file != nil do
      {:reply, :ok, state}
    else
      years = "#{year}#{year + 1}"
      filename = "PL0#{20_000 + game_id}.HTM"
      url = "http://www.nhl.com/scores/htmlreports/#{years}/#{filename}"
      response = HTTPoison.get! url
      {:reply, :ok, {year, game_id, response.body}}
    end
  end
end
