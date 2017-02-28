module Gorgon
  module PipeForker
    def pipe_fork
      stdin = Pipe.new(*IO.pipe)
      pid = fork do
        stdin.write.close
        STDIN.reopen(stdin.read)
        stdin.read.close

        yield

        exit
      end

      stdin.read.close

      return pid, stdin.write
    end

    private

    Pipe = Struct.new(:read, :write)
  end
end
