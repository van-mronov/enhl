defmodule ENHL.Fetcher do
  @doc """
  Gets a report from the `fetcher` by `season_id` and `agame_id`.
  """
  def get_report(_fetcher, _season_id, game_id) do
    years = "20092010"
    filename = "PL0#{20_000 + game_id}.HTM"
    url = "http://www.nhl.com/scores/htmlreports/#{years}/#{filename}"
    {:ok, resp} = HTTPoison.get! url
    resp.body
  end
end
