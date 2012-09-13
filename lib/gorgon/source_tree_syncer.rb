class SourceTreeSyncer
  attr_accessor :exclude
  attr_reader :sys_command

  SYS_COMMAND = 'rsync'
  OPTS = '-az'

  def initialize source_tree_path
    @source_tree_path = source_tree_path
    @exclude = []
  end

  def sync
    exclude_opt = "--exclude " + @exclude.join(" --exclude ") if @exclude and @exclude.any?

    @tempdir = Dir.mktmpdir("gorgon")
    Dir.chdir(@tempdir)
    @sys_command = "#{SYS_COMMAND} #{OPTS} #{exclude_opt} -r --rsh=ssh #{@source_tree_path}/* ."
    system(@sys_command)

    return $?.exitstatus == 0
  end

  def remove_temp_dir
    FileUtils::remove_entry_secure(@tempdir)
  end
end
