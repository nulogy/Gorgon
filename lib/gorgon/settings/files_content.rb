module Settings
  class FilesContent
    attr_accessor :amqp_host, :file_server_host, :sync_exclude, :files, :originator_log_file,
      :callbacks, :callbacks_dir

    TEST_UNIT_GLOB = "test/**/*_test.rb"
    RSPEC_GLOB = "spec/**/*_spec.rb"

    def initialize
      @files = []
      @files << FilesContent::TEST_UNIT_GLOB if Dir.exist?('test')
      @files << FilesContent::RSPEC_GLOB if Dir.exist?('spec')
    end

    DEFAULT_HOST = 'localhost'
    def self.get_amqp_host
      puts "AMQP host (default '#{DEFAULT_HOST}')? "
      return get_input_or_default(DEFAULT_HOST)
    end

    def self.get_file_server_host
      puts "File Server host (default '#{DEFAULT_HOST}')? "
      return get_input_or_default(DEFAULT_HOST)
    end

    private

    def self.get_input_or_default(default)
      input = $stdin.gets.chomp
      (input == '') ? default : input
    end
  end
end
