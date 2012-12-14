# Facade to all settings class

require 'gorgon/settings/simple_project_files_content'
#require 'gorgon/settings/rails_project_files_content'

module Settings
  class InitialFilesCreator
    GORGON_JSON_FILE = 'gorgon.json'

    # TODO: we may change this, so it knows what Creator to use according to the Gemfile, so the user doesn't need to specify 'framework'
    def self.run framework
      if framework.nil?
        create_files SimpleProjectFilesContent.new
      elsif framework == 'rails'
        create_files RailsProjectFilesContent.new
      else
        $stderr.puts "Unknown framework"
        exit(1)
      end
    end

    def self.create_files content
      self.create_gorgon_json content
    end

    private
    def self.create_gorgon_json content
      if File.exist? GORGON_JSON_FILE
        puts "gorgo.json exists. Skipping..."
        return
      end

      config = {
        connection: {host: content.amqp_host},
        job: {
          sync_exclude: content.sync_exclude
        },
        files: content.files
      }

      File.open(GORGON_JSON_FILE, 'w') do |f|
        Yajl::Encoder.encode(config, f, :pretty => true, :indent => "  ")
      end
    end
  end
end
