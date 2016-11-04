defmodule EdiStream.Parser.Helpers do
  def parse_stream(stream, parser, state) do
    ExParsec.parse(%EdiStream.Parser.StreamInput{stream: stream}, parser, state)
  end
end
