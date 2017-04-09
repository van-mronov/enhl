defmodule ENHL.ReportTest do
  use ExUnit.Case, async: true

  test "parse game info" do
    {:ok, report} = ENHL.Registry.report(2009, 20)
    ENHL.Report.fetch(report)
    {:ok, result} = ENHL.Report.parse_game_info(report)

    assert result == nil
  end
end