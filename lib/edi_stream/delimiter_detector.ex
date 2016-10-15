defmodule EdiStream.DelimiterDetector do

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

  defp determine_separators(io_thing) do
    read_data = IO.binread(io_thing, 4)
    case read_data do
      <<_::24, f_sep::binary>> -> determine_segment_separator(io_thing, f_sep)
      _ -> {:error, {:parse_field_separator_failed, read_data}}
    end
  end

  def find_separators(io_thing) do
    {:ok, current_position} = :file.position(io_thing, :cur)
    sep_reader = determine_separators(io_thing)
    {:ok, _} = :file.position(io_thing, current_position)
    case sep_reader do
      {:error, other} -> {:error, other}
      x -> x
    end
  end
end
