defmodule EdiStream.Etf do
  import ExParsec.Base
  import ExParsec.Helpers

  alias ExParsec.Parser

  defmacro set_parser_state(parser_state, state, new_state) do
    quote do
      %ExParsec.Parser{unquote(parser_state) | state: %EdiStream.Parser.ParserState{unquote(state) | unquote_splicing(new_state)}}
    end
  end

  defparser st() in p do
    state = p.state
    case state.current_loop do
      :FUNCTIONAL_GROUP -> case Parser.get(p) do
        {new_state, ["ST"|_] = seg} -> success(set_parser_state(new_state, state, [current_loop: :L834]), [ST: seg])
        {_, e} -> failure(:error, ["ST expected #{inspect e} found"])
      end
      _ -> failure(:error, ["ST encountered outside of an 834 loop"])
    end
  end


  defparser segment_matcher(expected_loop, new_loop, tag_name, do: check_fun) in p do
    state = p.state
    current_loop = state.current_loop
    {new_state, seg} = Parser.get(p)
    checkit = check_fun
    case checkit.(seg) do
      {true, check_result} -> 
        case current_loop do
          ^expected_loop -> success(set_parser_state(new_state, state, [current_loop: new_loop]), check_result)
          _ -> failure(:error, ["#{inspect tag_name} encountered outside of an 834 loop"])
        end
      {false, error} -> failure(:error, ["#{tag_name} expected #{inspect seg} found"])
    end
  end

  defparser gs() in p do
    (segment_matcher(:INTERCHANGE, :FUNCTIONAL_GROUP, :GS) do
      fn
        ["GS"|_] = segment-> {true, [GS: segment]}
        _ -> {false, "NOT GS"}
      end
    end).(p)
  end

  defparser se() in p do
    (segment_matcher(:L834, :L834, :SE) do
      fn
        (["SE"|_] = segment) -> {true, [SE: segment]}
        _ -> {false, "NOT SE"}
      end
    end).(p)
  end

  defparser isa() in p do
    state = p.state
    case state.current_loop do
      nil -> case Parser.get(p) do
        {new_state, ["ISA"|_] = seg} -> success(set_parser_state(new_state, state, [current_loop: :INTERCHANGE]), [ISA: seg])
        {new_state, e} -> failure(:error, ["ISA expected #{inspect e} found"])
      end
      _ -> failure(:error, ["ISA encountered outside of an 834 loop"])
    end
  end

  defparser l834() in p do
    sequence([isa, gs, st, se]).(p)
  end

  def parse(input) do
    EdiStream.Parser.Helpers.parse_stream(input, l834, %EdiStream.Parser.ParserState{current_loop: nil})
  end
end
