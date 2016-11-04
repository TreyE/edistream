defmodule EdiStream.SegmentStreamer do
  @type segment_streaming_state :: tuple
  @type segment :: any

  @spec segment_streamer(segment_streaming_state) :: {:halt, segment_streaming_state} | {[segment], segment_streaming_state}
  defp segment_streamer({f_sep, s_sep, fields, current_field, counter, {:done, io_thing}}) do
    {:halt, {f_sep, s_sep, fields, current_field, counter, io_thing}}
  end

  defp segment_streamer({f_sep, s_sep, fields, current_field, counter, io_thing}) do
    case EdiStream.BufferedFileStream.read(io_thing) do
      {:error, reason} -> raise reason
      {stream, :eof} -> emit_leftovers({f_sep, s_sep, fields, current_field, counter, stream})
      {stream, data} -> 
        case step_segment(data, f_sep, s_sep, fields, current_field, counter) do
          {^f_sep, ^s_sep, new_fields, new_cf, new_counter, nil} -> segment_streamer({f_sep, s_sep, new_fields, new_cf, new_counter, stream})
          {^f_sep, ^s_sep, new_fields, new_cf, new_counter, seg} -> {[seg], {f_sep, s_sep, new_fields, new_cf, new_counter, stream}}
        end
    end
  end

  defp step_segment(data, f_sep, s_sep, fields, current_field, counter) do
    case data do
      ^f_sep -> {f_sep, s_sep, [current_field|fields], <<>>, counter, nil}
      ^s_sep -> {f_sep, s_sep, [], <<>>, counter + 1, clean_fields(Enum.reverse([current_field|fields]))}
      _ -> {f_sep, s_sep, fields, current_field <> data, counter, nil}
    end
  end

  defp emit_leftovers({f_sep, s_sep, [], <<>>, counter, io_thing}) do
    {[], {f_sep, s_sep, [], <<>>, counter, {:done, io_thing}}}
  end

  defp emit_leftovers({f_sep, s_sep, fields, current_field, counter, io_thing}) do
    {[{:leftovers, clean_fields(Enum.reverse([current_field|fields]))}], {f_sep, s_sep, fields, current_field, counter, {:done, io_thing}}}
  end

  @spec segment_stream(IO.t) :: Stream.t
  def segment_stream(io_thing) do
    sep_reader = EdiStream.DelimiterDetector.find_separators(io_thing)
    case sep_reader do
      {:ok, f_sep, s_sep} -> 
        stream = EdiStream.BufferedFileStream.new(io_thing)
        acc = {}
        {:ok, 
           Stream.resource(fn -> {f_sep, s_sep, [], <<>>, 0, stream} end,
                           fn acc -> segment_streamer(acc) end,
                           fn acc -> acc end)
        }
      {:error, other} -> {:error, other}
    end
  end


  defp clean_fields(fields) do
    Enum.map(fields, &String.strip/1)
  end
end
