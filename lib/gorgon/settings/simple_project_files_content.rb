require 'gorgon/settings/files_content'

module Gorgon
  module Settings
    class SimpleProjectFilesContent < FilesContent
      def initialize
        super
        @amqp_host = FilesContent.get_amqp_host
        @file_server_host = FilesContent.get_file_server_host
        @sync_exclude = [".git", ".rvmrc"]
        @originator_log_file = 'gorgon-originator.log'
        @failed_files = 'gorgon-failed-files.json'
      end
    end
  end
end
