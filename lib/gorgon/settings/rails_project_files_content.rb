require 'gorgon/settings/files_content'

module Settings
  class RailsProjectFilesContent < FilesContent
    def initialize
      super
      @amqp_host = FilesContent.get_amqp_host
      @file_server_host = FilesContent.get_file_server_host
      @sync_exclude = [".git", ".rvmrc","tmp","log","doc"]
      @originator_log_file = 'log/gorgon-originator.log'
      create_callbacks
    end

    private

    def create_callbacks
      @callbacks_dir = "#{get_app_subdir}gorgon_callbacks"
      @callbacks = [{name: :after_sync, file_name: "after_sync.rb",
                      content: after_sync_content},
                    {name: :before_creating_workers, file_name: "before_creating_workers.rb",
                      content: before_creating_workers_content},
                    {name: :after_creating_workers, file_name: "after_creating_workers.rb",
                      content: after_creating_workers_content},
                    {name: :before_start, file_name: "before_start.rb",
                      content: before_start_content}]
    end

    def get_app_subdir
      if Dir.exist? "test"
        "test/"
      elsif Dir.exist? "spec"
        "spec/"
      elsif Dir.exist? "lib"
        "lib/"
      else
        ""
      end
    end

    def after_sync_content
      <<-'CONTENT'
require 'bundler'
require 'open4'

Bundler.with_clean_env do
  BUNDLE_LOG_FILE||="/tmp/gorgon-bundle-install.log "

  pid, stdin, stdout, stderr = Open4::popen4 "bundle install > #{BUNDLE_LOG_FILE} 2>&1 "

  ignore, status = Process.waitpid2 pid

  if status.exitstatus != 0
    raise "ERROR: 'bundle install' failed.\n#{stderr.read}"
  end
end
CONTENT
    end

    def before_creating_workers_content
      <<-'CONTENT'
ENV["TEST_ENV_NUMBER"] = Process.pid.to_s
ENV["RAILS_ENV"] = 'remote_test'

pid, stdin, stdout, stderr = Open4::popen4 "TEST_ENV_NUMBER=#{Process.pid.to_s} RAILS_ENV='remote_test' bundle exec rake db:setup"
ignore, status = Process.waitpid2 pid

if status.exitstatus != 0
  raise "ERROR: 'rake db:setup' failed.\n#{stderr.read}\n#{stdout.read}"
end

spec_helper_file = File.expand_path('../../spec_helper.rb', __FILE__)
test_helper_file = File.expand_path('../../test_helper.rb', __FILE__)

require spec_helper_file if File.exist?(spec_helper_file)
require test_helper_file if File.exist?(test_helper_file)
CONTENT
    end

    def after_creating_workers_content
      <<-'CONTENT'
require 'rake'
load './Rakefile'

begin
  if Rails.env = 'remote_test'
    Rake::Task['db:drop'].execute
  end
rescue Exception => ex
  puts "Error dropping test database:\n  #{ex}"
end
      CONTENT
    end

    def before_start_content
      <<-'CONTENT'
require 'rake'
load './Rakefile'

begin
  Rails.env = 'remote_test'
  ENV['TEST_ENV_NUMBER'] = Process.pid.to_s

  Rake::Task['db:reset'].invoke
end

CONTENT
    end
  end
end
