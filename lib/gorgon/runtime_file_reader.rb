require 'yajl'

class RuntimeFileReader

  def initialize(runtime_filename, options={})
    @runtime_filename = runtime_filename || ""
    @options = options
  end

  def old_files
    @old_files ||= unless File.file?(@runtime_filename)
                     []
                   else
                     File.open(@runtime_filename, 'r') do |f|
                       parser = Yajl::Parser.new
                       hash = parser.parse(f)
                       return [] if hash.nil?
                       hash.select!{|k,v| v[0].to_sym==:failed} if @options[:failures]
                       hash.keys
                     end
                   end
  end

  def sorted_files(current_files = [])
    if @options[:failures]
      self.old_files & current_files
    else
      (self.old_files+current_files).uniq - (self.old_files-current_files)
    end
  end

end

