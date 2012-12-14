module Settings
  class FilesContent
    attr_accessor :amqp_host, :sync_exclude, :files, :originator_log_file

    TEST_UNIT_GLOB = "test/**/*_test.rb"
    RSPEC_GLOB = "spec/**/*_spec.rb"

    def initialize
      @files = []
      @files << FilesContent::TEST_UNIT_GLOB if Dir.exist?('test')
      @files << FilesContent::RSPEC_GLOB if Dir.exist?('spec')
      @originator_log_file = 'log/gorgon-originator.log'
    end

    DEFAULT_AMQP_HOST = 'localhost'
    def self.get_amqp_host
      puts "AMQP host (default '#{DEFAULT_AMQP_HOST}')? "
      input = $stdin.gets.chomp
      if input == ""
        return DEFAULT_AMQP_HOST
      else
        return input
      end
    end
  end
end
