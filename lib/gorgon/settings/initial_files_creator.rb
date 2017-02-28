require 'gorgon/settings/simple_project_files_content'
require 'gorgon/settings/rails_project_files_content'

module Gorgon
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
          puts "#{GORGON_JSON_FILE} exists. Skipping..."
          return
        end

        config = {
          connection: {host: content.amqp_host},
          failed_files: content.failed_files,
          file_server: {host: content.file_server_host},
          files: content.files,
          job: {
            sync: {
              exclude: content.sync_exclude,
              rsync_transport: "ssh"
            }
          },
          originator_log_file: content.originator_log_file,
          runtime_file: content.runtime_file,
        }

        if content.callbacks
          create_callback_file(content)

          config[:job][:callbacks] = {
            callbacks_class_file: content.callbacks[:file_name]
          }
        end

        puts "Creating #{GORGON_JSON_FILE}..."
        File.open(GORGON_JSON_FILE, 'w') do |f|
          Yajl::Encoder.encode(config, f, :pretty => true, :indent => "  ")
        end
      end

      def self.create_callback_file(content)
        file_path = content.callbacks[:file_name]
        if File.exist? file_path
          puts "#{file_path} already exists. Skipping..."
          return
        end

        puts "Creating #{file_path}..."
        FileUtils.mkdir_p(File.dirname(file_path))
        File.open(file_path, 'w') do |f|
          f.write content.callbacks[:file_content]
        end
      end
    end
  end
end
