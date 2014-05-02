require "tmpdir"

class RsyncDaemon
  #for now, creates a readonly rsync daemon for the current directory on the mountpath "src"
  RSYNC_DIR_NAME = "#{Dir.tmpdir}/gorgon_rsync_daemon"
  RSYNC_PORT = 43434
  PID_FILE = 'rsync.pid'

  def self.start(directory_bucket)
    if directory_bucket.nil? || !File.directory?(directory_bucket)
      $stderr.puts "Please, expecify a valid directory."
      return false
    end

    if !port_available?
      puts port_busy_msg
      return false
    end

    Dir.mkdir(RSYNC_DIR_NAME)
    success = false
    Dir.chdir(RSYNC_DIR_NAME) do
      File.write("rsyncd.conf", rsyncd_config_string(directory_bucket))

      success = Kernel.system("rsync --daemon --config rsyncd.conf")
    end

    success
  end

  def self.stop
    if !File.directory?(RSYNC_DIR_NAME)
      puts "ERROR: Directory '#{RSYNC_DIR_NAME}' doesn't exists. Maybe rsync daemon is not running!"
      return false
    end

    success = nil
    Dir.chdir(RSYNC_DIR_NAME) do
      pid = File.read(PID_FILE)
      success = Kernel.system("kill #{pid}")
    end

    if success
      FileUtils::remove_entry_secure(RSYNC_DIR_NAME)
      return true
    else
      return false
    end
  end

  private

  def self.rsyncd_config_string(directory_bucket)
    return <<-EOF
port = #{RSYNC_PORT}
pid file = #{PID_FILE}

[src]
  path = #{directory_bucket}
  read only = false
  use chroot = false
EOF
  end

  def self.port_available?
    begin
      s = TCPServer.new('localhost', RSYNC_PORT)
      s.close
      return true
    rescue Errno::EADDRINUSE => _
      return false
    end
  end

  def self.port_busy_msg
<<-MSG
  ERROR: port #{RSYNC_PORT} is being used. Maybe another rsync daemon is running.
  Kill pid in #{RSYNC_DIR_NAME}/#{PID_FILE} or check no other process is using that port."
MSG
  end
end
