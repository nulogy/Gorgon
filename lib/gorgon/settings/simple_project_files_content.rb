require 'gorgon/settings/files_content'

module Settings
  class SimpleProjectFilesContent < FilesContent
    def initialize
      super
      @amqp_host = FilesContent.get_amqp_host
      @sync_exclude = [".git", ".rvmrc"]
    end
  end
end
