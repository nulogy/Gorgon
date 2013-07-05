require "tmpdir"

class RsyncDaemon
  #for now, creates a readonly rsync daemon for the current directory on the mountpath "src"

  def initialize
    @project_directory = Dir.pwd
    @started = false
  end

  def start
    return if @started
    @tmpdir = Dir.mktmpdir("gorgon")
    success = nil
    Dir.chdir(@tmpdir) do
      File.write("rsyncd.conf", rsyncd_config_string(@project_directory))

      success = Kernel.system("rsync --daemon --config rsyncd.conf")
    end

    if success
      @started = true
      return true
    else
      return false
    end
  end

  def stop
    return unless @started

    success = nil
    Dir.chdir(@tmpdir) do
      pid = File.read("rsync.pid")
      success = Kernel.system("kill #{pid}")
    end

    if success
      @started = false
      return true
    else
      return false
    end
  end

  private

  def rsyncd_config_string(shared_dir)
    return <<-EOF
port = 43434
pid file = rsync.pid

[src]
  path = #{@project_directory}
  read only = true
  use chroot = false
EOF
  end
end