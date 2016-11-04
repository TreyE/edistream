defmodule EdiStream.Parser.StreamInput do
  defstruct [stream: nil]
end

defimpl ExParsec.Input, for: EdiStream.Parser.StreamInput do
  def get(stream,_) do
    case Enum.to_list(Enum.take(stream.stream, 1)) do
      [] -> :eof
      [val] -> {%EdiStream.Parser.StreamInput{ stream: Enum.drop(stream.stream, 1) }, val}
    end
  end
end
