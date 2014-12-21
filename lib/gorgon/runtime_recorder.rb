require 'gorgon/configuration'
require 'fileutils'

DIVIDER = '=>'

module RuntimeRecorder

  @records ||= {}

  def self.records
    @records
  end

  def self.clear_records!
    @records = {}
  end

  def self.record!(filename, runtime)
    @records[filename] = runtime
  end

  def self.recorded_specs_list_file # returns filename
    return "" unless File.file?("gorgon.json")
    @recorded_specs_list_file ||= Configuration.load_configuration_from_file("gorgon.json")[:recorded_specs_list_file] || ""
  end

  def self.make_directories!
    dirname = File.dirname(self.recorded_specs_list_file)
    FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
  end

  def self.write_records_to_file!
    return if self.recorded_specs_list_file.nil? || self.recorded_specs_list_file.empty?
    self.make_directories!
    File.open(self.recorded_specs_list_file, 'w') do |file|
      file.write self.records.sort_by{|k, v| -1*v}.map{|k, v| "#{k}#{DIVIDER}#{v.to_s}"}.join("\n")
    end
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

