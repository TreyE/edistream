defmodule EdiStream.SegmentStreamer do

  defp read_s_sep_for_io(io_thing) do
    data = IO.binread(io_thing, 2)
    case data do
      <<_::8, s_sep::binary>> -> {:halt, {:ok, s_sep}}
      :eof -> {:halt, {:error, :data_to_short_for_segment_separator}}
      {:error, reason} -> {:halt, {:error, {:io_error, reason}}}
    end
  end

  defp finished_finding_s_sep?(io_thing, counter) do
    case counter do
      14 -> read_s_sep_for_io(io_thing)
      _ -> {:cont, counter + 1}
    end
  end

  defp determine_segment_separator(io_thing, f_sep) do
    found_item = Enum.reduce_while(Stream.cycle([1,2]), 0, fn(_, acc) ->
      val = IO.binread(io_thing, 1)
      case val do
        :eof -> {:halt, {:error, :data_to_short_for_segment_separator}}
        {:error, reason} -> {:halt, {:error, {:io_error, reason}}}
        ^f_sep -> finished_finding_s_sep?(io_thing, acc)
        _ -> {:cont, acc}
      end
    end)
    case found_item do
      {:ok, s_sep} -> {:ok, f_sep, s_sep}
      {:error, other} -> {:error, {:no_segment_separator, other}}
    end
  end

  def determine_separators(io_thing) do
    read_data = IO.binread(io_thing, 4)
    case read_data do
      <<_::24, f_sep::binary>> -> determine_segment_separator(io_thing, f_sep)
      _ -> {:error, {:parse_field_separator_failed, read_data}}
    end
  end

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

  def stream_segments(io_thing, start_callback, segment_callback, leftover_callback, error_callback, callback_state \\ []) do
    {:ok, current_position} = :file.position(io_thing, :cur)
    sep_reader = determine_separators(io_thing)
    {:ok, _} = :file.position(io_thing, current_position)
    case sep_reader do
      {:ok, f_sep, s_sep} -> 
        start_callback.(callback_state, f_sep, s_sep)
        perform_streaming(io_thing, f_sep, s_sep, segment_callback, leftover_callback, callback_state)
      {:error, other} -> 
        error_callback.(callback_state, other)
        {:error, other}
    end
  end

  defp clean_fields(fields) do
    Enum.map(fields, &String.strip/1)
  end

  defp perform_streaming(io_thing, f_sep, s_sep, callback, leftover_callback, callback_state) do
    stream = IO.binstream(io_thing, 1024)
    {leftover_fields, leftover_field, current_count} = Enum.reduce(stream, {[], "", 0}, fn(x, acc) -> 
      {fs, cf, cnt} = acc
      stream_data(x, f_sep, s_sep, fs, cf, callback, cnt, callback_state)
    end)
    leftover_f = String.strip(leftover_field)
    leftover_fs = clean_fields(Enum.reverse(leftover_fields))
    case {leftover_fs, leftover_f} do
      {[], ""} -> :ok 
      _ -> 
        leftover_callback.(callback_state, leftover_fs, leftover_f, current_count)
        {:warning, {:leftovers, leftover_fs, leftover_f}}
    end
  end
end
