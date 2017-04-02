defmodule ENHL.ReportProvider do
  use GenServer

  @doc """
  Starts the fetcher with the given `name`.
  """
  def start_link(name) do
    GenServer.start_link(__MODULE__, :ok, name: name)
  end

  @doc """
  Fetches the report by `year` and `game_id`. stored in `server`.

  Returns `{:ok, file}` if the report exists, `:error` otherwise.
  """
  def fetch(server, year, game_id) do
    GenServer.call(server, {:fetch, year, game_id})
  end

  @doc """
  Stops the fetcher.
  """
  def stop(server) do
    GenServer.stop(server)
  end

  ## Server Callbacks

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_call({:fetch, year, game_id}, _from, games) do
    file = get_report!(year, game_id)
    {:reply, {:ok, file}, games}
  end

  defp get_report!(year, game_id) do
    years = "#{year}#{year + 1}"
    filename = "PL0#{20_000 + game_id}.HTM"
    url = "http://www.nhl.com/scores/htmlreports/#{years}/#{filename}"
    {:ok, resp} = HTTPoison.get! url
    resp.body
  end
end
