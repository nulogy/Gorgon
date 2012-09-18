class SourceTreeSyncer
  attr_accessor :exclude
  attr_reader :sys_command

  SYS_COMMAND = 'rsync'
  OPTS = '-az'
  EXCLUDE_OPT = "--exclude"

  def initialize source_tree_path
    @source_tree_path = source_tree_path
    @exclude = []
  end

  def sync
    @tempdir = Dir.mktmpdir("gorgon")
    Dir.chdir(@tempdir)

    exclude_opt = build_exclude_opt
    @sys_command = "#{SYS_COMMAND} #{OPTS} #{exclude_opt} -r --rsh=ssh #{@source_tree_path}/ ."
    system(@sys_command)

    return $?.exitstatus == 0
  end

  def remove_temp_dir
    FileUtils::remove_entry_secure(@tempdir)
  end

  private

  def build_exclude_opt
    return "" if @exclude.nil? or @exclude.empty?

    @exclude.unshift("")
    @exclude.join(" #{EXCLUDE_OPT} ")
  end
end
