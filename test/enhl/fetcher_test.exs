defmodule ENHL.FetcherTest do
  use ExUnit.Case, async: true

  test "download report id" do
    {:ok, fetcher} = ENHL.Fetcher.start_link
    assert ENHL.Fetcher.get_report(fetcher, 93, 100) == nil
  end
end
