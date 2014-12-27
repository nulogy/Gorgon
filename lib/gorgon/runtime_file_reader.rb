require 'yajl'

class RuntimeFileReader

  def initialize(runtime_filename)
    @runtime_filename = runtime_filename || ""
  end

  def old_files
    @old_files ||= unless File.file?(@runtime_filename)
                     []
                   else
                     File.open(@runtime_filename, 'r') do |f|
                       parser = Yajl::Parser.new
                       hash = parser.parse(f)
                       hash.nil? ? [] : hash.keys
                     end
                   end
  end

  def sorted_files(current_files = [])
    (self.old_files+current_files).uniq - (self.old_files-current_files)
  end

end

