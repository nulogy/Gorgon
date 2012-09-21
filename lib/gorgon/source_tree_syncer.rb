require 'open4'

class SourceTreeSyncer
  attr_accessor :exclude
  attr_reader :sys_command, :output, :errors

  SYS_COMMAND = 'rsync'
  OPTS = "-azr --timeout=5 --rsh='ssh -o NumberOfPasswordPrompts=0 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'"
  EXCLUDE_OPT = "--exclude"

  def initialize source_tree_path
    @source_tree_path = source_tree_path
    @exclude = []
  end

  def sync
    @tempdir = Dir.mktmpdir("gorgon")
    Dir.chdir(@tempdir)

    exclude_opt = build_exclude_opt
    @sys_command = "#{SYS_COMMAND} #{OPTS} #{exclude_opt} #{@source_tree_path}/ ."

    pid, stdin, stdout, stderr = Open4::popen4 @sys_command
    stdin.close

    @output, @errors = [stdout, stderr].map { |p| begin p.read ensure p.close end }

    ignore, status = Process.waitpid2 pid
    @exitstatus = status.exitstatus
  end

  def success?
    @exitstatus == 0
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
