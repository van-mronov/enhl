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
  Returns the url of the `report`.

  Returns `{:ok, url}`.
  """
  def url(report) do
    GenServer.call(report, :url)
  end

  @doc """
  Fetches the report from NHL site.

  Returns `:ok` if the report fetched successfully, `:error` otherwise.
  """
  def fetch(report) do
    GenServer.call(report, :fetch, 30000)
  end

  @doc """
  Parses the game info from report.

  Returns `:ok` if the report parsed successfully, `:error` otherwise.
  """
  def parse_game_info(report) do
    GenServer.call(report, :parse_game_info)
  end

  @doc """
  Returns the game_info of the `report`.

  Returns `{:ok, game_info}`.
  """
  def game_info(report) do
    GenServer.call(report, :game_info)
  end

  ## Server Callbacks

  def init(year: year, game_id: game_id) do
    years = "#{year}#{year + 1}"
    filename = "PL0#{20_000 + game_id}.HTM"
    url = "http://www.nhl.com/scores/htmlreports/#{years}/#{filename}"

    {:ok, {year, game_id, url, nil, nil}}
  end

  def handle_call(:year, _from, {year, _game_id, _url, _raw_html, _game_info} = state) do
    {:reply, {:ok, year}, state}
  end

  def handle_call(:game_id, _from, {_year, game_id, _url, _raw_html, _game_info} = state) do
    {:reply, {:ok, game_id}, state}
  end

  def handle_call(:url, _from, {_year, _game_id, url, _raw_html, _game_info} = state) do
    {:reply, {:ok, url}, state}
  end

  def handle_call(:game_info, _from, {_year, _game_id, _url, _raw_html, game_info} = state) do
    {:reply, {:ok, game_info}, state}
  end

  def handle_call(:fetch, _from, {year, game_id, url, raw_html, game_info} = state) do
    # TODO: add error replies
    if raw_html != nil do
      {:reply, :ok, state}
    else
      response = HTTPoison.get! url
      {:reply, :ok, {year, game_id, url, response.body, game_info}}
    end
  end

  def handle_call(:parse_game_info, _from, {year, game_id, url, raw_html, game_info} = state) do
    # TODO: add error replies

    props = Floki.find(raw_html, "td[align='center']")

    if game_id != actual_game_id(props) do
      {:reply, {:error, :invalid_game_id}, state}
    else
      game_info = Map.merge(%{game_id: game_id}, parse_arena_info(props))
      game_info = Map.merge(game_info, parse_game_time(props))

      {:reply, :ok, {year, game_id, url, raw_html, game_info}}
    end
  end

  defp actual_game_id(props) do
    props
    |> Enum.fetch!(12)
    |> Floki.text
    |> String.split(" ")
    |> List.last
    |> String.to_integer
  end

  defp parse_arena_info(props) do
    [attendance_str, arena] = props
                              |> Enum.fetch!(10)
                              |> Floki.text
                              |> convert_nbsp
                              |> String.replace("at", "@")
                              |> String.split("@")
                              |> Enum.map(fn x -> x |> String.trim end)

    attendance = attendance_str
                 |> String.split(" ")
                 |> List.last
                 |> String.replace(",", "")
                 |> String.to_integer

    %{arena: arena, attendance: attendance}
  end

  defp parse_game_time(props) do
    date = props |> Enum.fetch!(9) |> Floki.text
    [start_time, end_time] = props
                             |> Enum.fetch!(11)
                             |> Floki.text
                             |> convert_nbsp
                             |> String.split(";")
                             |> Enum.map(fn x -> x |> String.trim
                                                   |> String.split(" ", parts: 2)
                                                   |> List.last
                                         end)

    %{start: parse_datetime(date, start_time), end: parse_datetime(date, end_time)}
  end

  defp convert_nbsp(input) do
    input
    |> String.to_charlist
    |> :binary.list_to_bin
    |> :binary.replace(<<160>>, <<" ">>, [:global]) # &nbsp;
  end

  defp parse_datetime(date, time) do
    Timex.parse!("#{time}, #{date}", "%k:%M %Z, %A, %B %e, %Y", :strftime)
  end
end
