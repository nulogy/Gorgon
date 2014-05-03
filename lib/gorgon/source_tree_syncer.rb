require 'open4'

class SourceTreeSyncer
  attr_accessor :exclude
  attr_reader :sys_command, :output, :errors

  SYS_COMMAND = 'rsync'
  OPTS = "-azr --timeout=5 --delete"
  EXCLUDE_OPT = "--exclude"

  def initialize source_tree_path
    @source_tree_path = source_tree_path
    @exclude = []
  end

  def sync
    return if blank_source_tree_path?

    @tempdir = Dir.mktmpdir("gorgon")
    Dir.chdir(@tempdir)

    @sys_command = "#{SYS_COMMAND} #{OPTS} #{build_exclude_opt} #{@source_tree_path}/ ."

    execute_command
  end

  def push
    return if blank_source_tree_path?

    @sys_command = "#{SYS_COMMAND} #{OPTS} #{build_exclude_opt} . #{@source_tree_path}"

    execute_command
  end

  def success?
    @exitstatus == 0
  end

  def remove_temp_dir
    FileUtils::remove_entry_secure(@tempdir) if @tempdir
  end

  private

  def execute_command
    pid, stdin, stdout, stderr = Open4::popen4 @sys_command
    stdin.close

    ignore, status = Process.waitpid2 pid

    @output, @errors = [stdout, stderr].map { |p| begin p.read ensure p.close end }

    @exitstatus = status.exitstatus
  end

  def blank_source_tree_path?
    if @source_tree_path.nil?
      @errors = "Source tree path cannot be nil. Check your gorgon.json file."
    elsif @source_tree_path.strip.empty?
      @errors = "Source tree path cannot be empty. Check your gorgon.json file."
    end

    if @errors
      @exitstatus = 1
      return true
    else
      return false
    end
  end

  def build_exclude_opt
    return "" if @exclude.nil? or @exclude.empty?

    exclude = [""] + @exclude
    exclude.join(" #{EXCLUDE_OPT} ")
  end
end
