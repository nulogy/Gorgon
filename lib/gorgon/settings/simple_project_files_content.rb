require 'gorgon/settings/files_content'

module Settings
  class SimpleProjectFilesContent < FilesContent
    def initialize
      super
      @amqp_host = FilesContent.get_amqp_host
      @sync_exclude = [".git", ".rvmrc"]
      @originator_log_file = 'gorgon-originator.log'
    end
  end
end
