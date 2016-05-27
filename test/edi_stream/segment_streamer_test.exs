defmodule EdiStream.SegmentStreamerTest do
  use ExUnit.Case
  doctest EdiStream.SegmentStreamer

  test "the truth" do
    callback = fn(cs, data, counter) -> IO.puts("#{inspect counter} : #{inspect data}") end
    leftover_callback = fn(cs, lfs, lf, counter) -> IO.puts("leftover: #{inspect lfs}, #{inspect lf}, #{inspect counter}") end
    error_callback = fn(cs, err) -> IO.puts("error: #{inspect err}") end
    {:ok, f} = :file.open("b2b_edi.csv", [:read, :binary])
    EdiStream.SegmentStreamer.stream_segments(f, callback, leftover_callback, error_callback)
  end
end
