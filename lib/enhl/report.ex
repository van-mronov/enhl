defmodule ENHL.Report do
  use GenServer

  @doc """
  Starts a new report.
  """
  def start_link(year, game_id), do: GenServer.start_link(__MODULE__, year: year, game_id: game_id)

  @doc """
  Returns the year of the `report`.

  Returns `{:ok, year}`.
  """
  def year(report), do: GenServer.call(report, :year)

  @doc """
  Returns the game_id of the `report`.

  Returns `{:ok, game_id}`.
  """
  def game_id(report), do: GenServer.call(report, :game_id)

  @doc """
  Returns the url of the `report`.

  Returns `{:ok, url}`.
  """
  def url(report), do: GenServer.call(report, :url)

  @doc """
  Returns the game_info of the `report`.

  Returns `{:ok, game_info}`.
  """
  def game_info(report), do: GenServer.call(report, :game_info)

  @doc """
  Returns the events of the `report`.

  Returns `{:ok, events}`.
  """
  def events(report), do: GenServer.call(report, :events)

  @doc """
  Fetches the report from NHL site.

  Returns `:ok` if the report fetched successfully, `:error` otherwise.
  """
  def fetch(report), do: GenServer.call(report, :fetch, 30000)

  @doc """
  Parses the game info from report.

  Returns `:ok` if the report parsed successfully, `:error` otherwise.
  """
  def parse_game_info(report), do: GenServer.call(report, :parse_game_info)

  @doc """
  Parses the game events from report.

  Returns `:ok` if the report parsed successfully, `:error` otherwise.
  """
  def parse_events(report), do: GenServer.call(report, :parse_events)

  ## Server Callbacks

  def init(year: year, game_id: game_id) do
    url = "http://www.nhl.com/scores/htmlreports/#{year}#{year + 1}/PL0#{20_000 + game_id}.HTM"
    {:ok, %{year: year, game_id: game_id, url: url, game_info: nil, events: nil, html: nil}}
  end

  def handle_call(:year,      _from, state), do: {:reply, {:ok, state.year},      state}
  def handle_call(:game_id,   _from, state), do: {:reply, {:ok, state.game_id},   state}
  def handle_call(:url,       _from, state), do: {:reply, {:ok, state.url},       state}
  def handle_call(:game_info, _from, state), do: {:reply, {:ok, state.game_info}, state}
  def handle_call(:events,    _from, state), do: {:reply, {:ok, state.events},    state}

  def handle_call(:fetch, _from, state) do
    # TODO: add error replies
    if state.html != nil, do:   {:reply, :ok, state},
                          else: {:reply, :ok, put_in(state.html, HTTPoison.get!(state.url).body)}
  end

  def handle_call(:parse_game_info, _from, state) do
    # TODO: add error replies
    props = Floki.find(state.html, "td[align='center']")
    if state.game_id != actual_game_id(props) do
      {:reply, {:error, :invalid_game_id}, state}
    else
      {:reply, :ok, put_in(state.game_info, parse_game_info(state.game_id, props))}
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

  defp parse_game_info(game_id, props) do
    %{game_id: game_id}
    |> Map.merge(parse_arena_info(props))
    |> Map.merge(parse_game_time(props))
    |> Map.merge(%{visitor: parse_team(props,  3, :away)})
    |> Map.merge(%{home:    parse_team(props, 16, :home)})
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

  defp parse_team(props, score_index, game_type) do
    [title, games] = props
                     |> Enum.fetch!(score_index + 2)
                     |> Floki.text
                     |> String.split("\n")

    games = games |> String.split
    game = games |> Enum.at(1) |> String.to_integer
    game_type_n = games |> List.last |> String.to_integer
    score = props |> Enum.fetch!(score_index)|> Floki.text |> String.to_integer

    %{:title => title, :game => game, game_type => game_type_n, :score => score}
  end
end
