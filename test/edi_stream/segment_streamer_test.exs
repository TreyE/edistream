defmodule EdiStream.SegmentStreamerTest do
  use ExUnit.Case
  doctest EdiStream.SegmentStreamer

  test "parse as stream" do
    {:ok, f} = :file.open("b2b_edi.csv", [:read, :binary])
    {:ok, stream} = EdiStream.SegmentStreamer.segment_stream(f)
    Enum.each(stream,
      fn x -> IO.puts("Data: #{inspect x}") end)
  end
end
