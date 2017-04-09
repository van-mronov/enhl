defmodule ENHL.ReportTest do
  use ExUnit.Case, async: true

  test "parse game info" do
    {:ok, report} = ENHL.Registry.report(2009, 20)
    ENHL.Report.fetch(report)
    ENHL.Report.parse_game_info(report)
    {:ok, result} = ENHL.Report.game_info(report)

    assert result == nil
  end
end
