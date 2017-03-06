require "logger"

module Gorgon
  module GLogger
    SIZE_1_MB = 1048576

    def initialize_logger log_file
      return unless log_file
      @logger =
        if log_file == "-"
          Logger.new($stdout)
        else
          Logger.new(log_file, 1, SIZE_1_MB)
        end
      @logger.datetime_format = "%Y-%m-%d %H:%M:%S "
    end

    def log text
      @logger.info(text) if @logger
    end

    def log_error text
      @logger.error(text) if @logger
    end
  end
end
