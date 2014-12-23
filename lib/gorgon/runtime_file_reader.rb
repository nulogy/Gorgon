require 'yajl'

class RuntimeFileReader

  def initialize(runtime_filename)
    @runtime_filename = runtime_filename || ""
  end

  def old_files
    @old_files ||= unless File.file?(@runtime_filename)
                     []
                   else
                     json = File.new(@runtime_filename, 'r')
                     parser = Yajl::Parser.new
                     parser.parse(json).keys
                   end
  end

  def sorted_files(current_files = [])
    (self.old_files+current_files).uniq - (self.old_files-current_files)
  end

end

