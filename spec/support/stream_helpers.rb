module Gorgon
  module StreamHelpers
    # Taken from http://stackoverflow.com/a/8959520/100466
    def silence_streams(*streams)
      original_streams = streams.map { |stream| stream.dup }
      streams.each do |stream|
        stream.reopen(dev_null)
        stream.sync = true
      end
      yield
    ensure
      streams.each_with_index do |stream, idx|
        stream.reopen(original_streams[idx])
      end
    end

    private

    def dev_null
      @dev_null ||= (RUBY_PLATFORM =~ /mswin/ ? 'NUL:' : '/dev/null')
    end
  end
end
