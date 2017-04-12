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

  def handle_call(:fetch, _from, %{html: html} = state) when is_nil(html) do
    {:reply, :ok, put_in(state.html, HTTPoison.get!(state.url).body)}
  end

  def handle_call(:fetch, _from, state) do
    # TODO: add error replies
    {:reply, :ok, state}
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

  def handle_call(:parse_events, _from, state) do
    events = state.html |> Floki.find("tr[class='evenColor']") |> Enum.map(&parse_event/1)
    {:reply, :ok, put_in(state.events, events)}
  end

  ## Private functions

  defp actual_game_id(props) do
    props
    |> text_element_value(12)
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
                              |> text_element_value(10)
                              |> convert_nbsp
                              |> String.replace("at", "@")
                              |> String.split("@")
                              |> Enum.map(&String.trim/1)

    attendance = attendance_str
                 |> String.split(" ")
                 |> List.last
                 |> String.replace(",", "")
                 |> String.to_integer

    %{arena: arena, attendance: attendance}
  end

  defp parse_game_time(props) do
    date = text_element_value(props, 9)
    [start_time, end_time] = props
                             |> text_element_value(11)
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
    [title, games] = props |> text_element_value(score_index + 2) |> String.split("\n")
    games = String.split(games)

    %{
      :title    => title,
      :game     => games |> Enum.at(1) |> String.to_integer,
      game_type => games |> List.last |> String.to_integer,
      :score    => int_element_value(props, score_index),
     }
  end

  defp parse_event(html) do
    html
    |> Floki.find("td")
    |> common_event_info
    |> Map.merge(parse_players(html |> Floki.find("table")))
  end

  defp common_event_info(props) do
    [time, elapsed] = text_element_value(props, 3) |> String.split

    %{
      event_id: int_element_value(props,  0),
      period:   int_element_value(props,  1),
      str:      text_element_value(props, 2),
      time:     time,
      elapsed:  elapsed,
      type:     text_element_value(props, 4),
      desc:     text_element_value(props, 5),
     }
  end

  defp parse_players(tables) when length(tables) == 0, do: %{}

  defp parse_players(tables) do
    visitor_players = tables |> Enum.at(0) |> parse_players_table
    offset = length(visitor_players) + 1
    home_players = tables |> Enum.at(offset) |> parse_players_table
    %{players: %{visitor: visitor_players, home: home_players}}
  end

  defp parse_players_table(html) when is_nil(html), do: []

  defp parse_players_table(html), do: Floki.find(html, "font") |> Enum.map(&parse_player/1)

  defp parse_player(html) do
    [position, name] = html
                       |> Floki.attribute("title")
                       |> List.first
                       |> String.split("-")
                       |> Enum.map(&String.trim/1)

    %{
      position: position,
      name:     name,
      number:   html |> Floki.text |> String.to_integer,
     }
  end

  defp text_element_value(props, index), do: props |> Enum.fetch!(index) |> Floki.text

  defp int_element_value(props, index), do: props |> text_element_value(index) |> String.to_integer
end
