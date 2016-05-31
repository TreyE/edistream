defmodule EdiStream.SegmentStreamerTest do
  use ExUnit.Case
  doctest EdiStream.SegmentStreamer

  test "the truth" do
    start_callback = fn(cs, f_s, s_s) -> IO.puts("Starting parse: #{inspect f_s} : #{inspect s_s}"); {:ok, []} end
    callback = fn(cs, data, counter) -> IO.puts("#{inspect counter} : #{inspect data}") end
    leftover_callback = fn(cs, lfs, lf, counter) -> IO.puts("leftover: #{inspect lfs}, #{inspect lf}, #{inspect counter}") end
    error_callback = fn(cs, err) -> IO.puts("error: #{inspect err}") end
    {:ok, f} = :file.open("b2b_edi.csv", [:read, :binary])
    EdiStream.SegmentStreamer.stream_segments(f, start_callback, callback, leftover_callback, error_callback)
  end
end
