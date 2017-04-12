defmodule ENHL.ReportTest do
  use ExUnit.Case, async: true

  test "year" do
    {:ok, report} = ENHL.Registry.report(2009, 37)
    {:ok, year} = ENHL.Report.year(report)

    assert year == 2009
  end

  test "game_id" do
    {:ok, report} = ENHL.Registry.report(2009, 37)
    {:ok, game_id} = ENHL.Report.game_id(report)

    assert game_id == 37
  end

  test "url" do
    {:ok, report} = ENHL.Registry.report(2009, 37)
    {:ok, url} = ENHL.Report.url(report)

    assert url == "http://www.nhl.com/scores/htmlreports/20092010/PL020037.HTM"
  end

  test "parse game info" do
    {:ok, report} = ENHL.Registry.report(2009, 37)
    ENHL.Report.fetch(report)
    ENHL.Report.parse_game_info(report)
    {:ok, result} = ENHL.Report.game_info(report)

    assert result.arena == "Scotiabank Place"
  end

  test "parse events without exceptions" do
    {:ok, report} = ENHL.Registry.report(2009, 37)
    ENHL.Report.fetch(report)
    ENHL.Report.parse_events(report)
    {:ok, events} = ENHL.Report.events(report)

    assert length(events) > 0
  end
end
