require 'gorgon/settings/simple_project_files_content'
require 'gorgon/settings/rails_project_files_content'

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
        file_server: {host: content.file_server_host},
        job: {
          sync_exclude: content.sync_exclude
        },
        files: content.files
      }

      log_file = content.originator_log_file
      config[:originator_log_file] = log_file if log_file

      if content.callbacks
        create_callback_files(content)

        config[:job][:callbacks] = content.callbacks.inject({}) do |callbacks, e|
          callbacks[e[:name]] = "#{content.callbacks_dir}/#{e[:file_name]}"
          callbacks
        end
      end

      puts "Creating #{GORGON_JSON_FILE}..."
      File.open(GORGON_JSON_FILE, 'w') do |f|
        Yajl::Encoder.encode(config, f, :pretty => true, :indent => "  ")
      end
    end

    def self.create_callback_files content
      FileUtils.mkdir_p content.callbacks_dir
      content.callbacks.each do |callback|
        create_callback_file content.callbacks_dir, callback
      end
    end

    def self.create_callback_file dir, callback
      file_path = "#{dir}/#{callback[:file_name]}"
      if File.exist? file_path
        puts "#{file_path} already exists. Skipping..."
        return
      end

      puts "Creating #{file_path}..."
      File.open(file_path, 'w') do |f|
        f.write callback[:content]
      end
    end
  end
end
