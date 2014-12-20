require 'gorgon/configuration'
require 'fileutils'

DIVIDER = '=>'

module RuntimeRecorder

  @records ||= {}

  def self.records
    @records
  end

  def self.record(filename, runtime)
    @records[filename] = runtime
  end

  def self.recorded_specs_list_file
    return "" unless File.file?("gorgon.json")
    @recorded_specs_list_file ||= Configuration.load_configuration_from_file("gorgon.json")[:recorded_specs_list_file]
    @recorded_specs_list_file ||= "" # return "" if no file is specified
  end

  def self.make_directories!
    dirname = File.dirname(self.recorded_specs_list_file)
    FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
  end

  def self.write_records_to_file!
    return if self.recorded_specs_list_file.nil? || self.recorded_specs_list_file.empty?
    self.make_directories!
    file = open(self.recorded_specs_list_file, 'w')
    file.truncate 0
    file.write self.records.sort_by{|k, v| -1*v}.map{|k, v| "#{k}#{DIVIDER}#{v.to_s}"}.join("\n")
    file.close
  end

  def self.recorded_files
    return [] unless File.file?(self.recorded_specs_list_file)
    File.readlines(self.recorded_specs_list_file).map{|line| line.split(DIVIDER).first}
  end

  def self.sorted_files(current_files)
    rec_files = self.recorded_files
    (rec_files+current_files).uniq - (rec_files-current_files)
  end

end

