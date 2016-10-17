defmodule EdiStream.SegmentStreamer do

  defp segment_streamer({f_sep, s_sep, fields, current_field, counter, io_thing}) do
    case IO.binread(io_thing, 512) do
      {:error, reason} -> raise reason
      :eof -> {:halt, {f_sep, s_sep, fields, current_field, counter, io_thing}}
      data -> 
        {fs, cfs, new_counter, segments} = stream_segs(data, f_sep, s_sep, fields, current_field, counter, [])
        {segments, {f_sep, s_sep, fs, cfs, new_counter, io_thing}}
    end
  end

  def segment_stream(io_thing) do
    sep_reader = EdiStream.DelimiterDetector.find_separators(io_thing)
    case sep_reader do
      {:ok, f_sep, s_sep} -> 
        acc = {}
        {:ok, 
           Stream.resource(fn -> {f_sep, s_sep, [], "", 0, io_thing} end,
                           fn acc -> segment_streamer(acc) end,
                           fn acc -> acc end)
        }
      {:error, other} -> {:error, other}
    end
  end

  def stream_segs(<<data::binary-size(1), rest::binary>>, f_sep, s_sep, fields, current_field, counter, current_segments) do
    case data do
      ^f_sep -> stream_segs(rest, f_sep, s_sep, [current_field|fields], "", counter, current_segments)
      ^s_sep ->
        stream_segs(rest, f_sep, s_sep, [], "", counter + 1, [clean_fields(Enum.reverse([current_field|fields]))|current_segments])
      _ -> stream_segs(rest, f_sep, s_sep, fields, current_field <> data, counter, current_segments)
    end
  end

  def stream_segs(<<>>, _f_sep, _s_sep, fields, current_field, counter, current_segs) do
    {fields, current_field, counter, Enum.reverse(current_segs)}
  end


  defp clean_fields(fields) do
    Enum.map(fields, &String.strip/1)
  end
end
