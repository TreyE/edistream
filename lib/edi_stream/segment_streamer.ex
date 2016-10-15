defmodule EdiStream.SegmentStreamer do

  def stream_data(<<data::binary-size(1), rest::binary>>, f_sep, s_sep, fields, current_field, callback, counter, callback_state) do
    case data do
      ^f_sep -> stream_data(rest, f_sep, s_sep, [current_field|fields], "", callback, counter, callback_state)
      ^s_sep ->
        callback.(callback_state, clean_fields(Enum.reverse([current_field|fields])), counter)
        stream_data(rest, f_sep, s_sep, [], "", callback, counter + 1, callback_state)
      _ -> stream_data(rest, f_sep, s_sep, fields, current_field <> data, callback, counter, callback_state)
    end
  end

  def stream_data(<<>>, _f_sep, _s_sep, fields, current_field, _callback, counter, _callback_state) do
    {fields, current_field, counter}
  end

  def stream_segments(io_thing, start_callback, segment_callback, finished_callback, callback_state \\ []) do
    sep_reader = EdiStream.DelimiterDetector.find_separators(io_thing)
    case sep_reader do
      {:ok, f_sep, s_sep} -> 
        {:ok, init_state} = start_callback.(callback_state, f_sep, s_sep)
        perform_streaming(io_thing, f_sep, s_sep, segment_callback, finished_callback, init_state)
      {:error, other} -> {:error, other}
    end
  end

  defp clean_fields(fields) do
    Enum.map(fields, &String.strip/1)
  end

  defp perform_streaming(io_thing, f_sep, s_sep, callback, finished_callback, callback_state) do
    stream = IO.binstream(io_thing, 1024)
    {leftover_fields, leftover_field, current_count} = Enum.reduce(stream, {[], "", 0}, fn(x, acc) -> 
      {fs, cf, cnt} = acc
      stream_data(x, f_sep, s_sep, fs, cf, callback, cnt, callback_state)
    end)
    leftover_f = String.strip(leftover_field)
    leftover_fs = clean_fields(Enum.reverse(leftover_fields))
    case {leftover_fs, leftover_f} do
      {[], ""} -> 
        finished_callback.(callback_state, leftover_fs, leftover_f, current_count)
        {:ok, current_count}
      _ -> 
        finished_callback.(callback_state, leftover_fs, leftover_f, current_count)
        {:warning, {:leftovers, leftover_fs, leftover_f}}
    end
  end
end
