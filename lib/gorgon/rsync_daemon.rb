require "tmpdir"

class RsyncDaemon
  #for now, creates a readonly rsync daemon for the current directory on the mountpath "src"
  RSYNC_DIR_NAME = "#{Dir.tmpdir}/gorgon_rsync_daemon"
  RSYNC_PORT = 43434
  PID_FILE = 'rsync.pid'

  def initialize
    @project_directory = Dir.pwd
    @started = false
  end

  def start
    return if @started

    if !port_available?
      puts port_busy_msg
      return false
    end
    
    Dir.mkdir(RSYNC_DIR_NAME)
    success = nil
    Dir.chdir(RSYNC_DIR_NAME) do
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
    Dir.chdir(RSYNC_DIR_NAME) do
      pid = File.read(PID_FILE)
      success = Kernel.system("kill #{pid}")
    end

    if success
      @started = false
      FileUtils::remove_entry_secure(RSYNC_DIR_NAME)
      return true
    else
      return false
    end
  end

  private

  def rsyncd_config_string(shared_dir)
    return <<-EOF
port = #{RSYNC_PORT}
pid file = #{PID_FILE}

[src]
  path = #{@project_directory}
  read only = true
  use chroot = false
EOF
  end

  def port_available?
    begin
      s = TCPServer.new('localhost', RSYNC_PORT)
      s.close
      return true
    rescue Errno::EADDRINUSE => _
      return false
    end
  end

  def port_busy_msg
<<-MSG
  ERROR: port #{RSYNC_PORT} is being used. Maybe another rsync daemon is running.
  Kill pid in #{RSYNC_DIR_NAME}/#{PID_FILE} or check no other process is using that port."
MSG
  end
end
