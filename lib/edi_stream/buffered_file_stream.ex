defmodule EdiStream.BufferedFileStream do
  defstruct [
    stream: nil,
    position: 0,
    buffer: <<>>
  ]

  @chunk_size 512

  def new(io_file) do
    %EdiStream.BufferedFileStream{
      stream: io_file
    }
  end

  def read(%EdiStream.BufferedFileStream{buffer: <<>>} = stream) do
    :file.position(stream.stream, stream.position)
    read_result = IO.binread(stream.stream, @chunk_size)
    case read_result do
      :eof -> {stream, :eof}
      data -> populate_buffer(data, stream.stream, stream.position)
    end
  end

  def read(%EdiStream.BufferedFileStream{buffer: <<first_byte::binary-size(1), rest::binary>>} = stream) do
    {%EdiStream.BufferedFileStream{stream: stream.stream, position: stream.position + 1, buffer: rest}, first_byte} 
  end

  defp populate_buffer(<<first_byte::binary-size(1), rest::binary>>, stream, position) do
    {
    %EdiStream.BufferedFileStream{
      position: position + 1,
      buffer: rest,
      stream: stream
    },
    first_byte
    }
  end
end
