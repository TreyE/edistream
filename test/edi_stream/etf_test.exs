defmodule EdiStream.EtfTest do
  use ExUnit.Case
  doctest EdiStream.Etf

  test "parse as stream" do
    {:ok, f} = :file.open("b2b_edi.csv", [:read, :binary])
    {:ok, stream} = EdiStream.SegmentStreamer.segment_stream(f)
    {:ok, state, result} = EdiStream.Etf.parse(stream)
  end
end
