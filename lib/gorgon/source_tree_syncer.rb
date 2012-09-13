class SourceTreeSyncer
  attr_accessor :exclude
  attr_reader :sys_command

  SYS_COMMAND = 'rsync'
  OPTS = '-az'

  def initialize source_tree_path
    @source_tree_path = source_tree_path
  end

  def sync
    @tempdir = Dir.mktmpdir("gorgon")
    Dir.chdir(@tempdir)
    @sys_command = "#{SYS_COMMAND} #{OPTS} -r --rsh=ssh #{@source_tree_path}/* ."
    system(@sys_command)

    return $?.exitstatus == 0
  end

  def remove_temp_dir
    FileUtils::remove_entry_secure(@tempdir)
  end
end
