require 'etc'
require 'fileutils'

class ListenerInstaller
  include Configuration

  GORGON_DIR=".gorgon"
  DEFAULT_NO_WORKERS = 4
  LISTENER_CONFIG_FILE = "gorgon_listener.json"
  GORGON_INIT_FILE = "/etc/init/gorgon.conf"

  def self.install
    ListenerInstaller.new.install
  end

  def install
    @configuration = load_configuration_from_file("gorgon.json")

    FileUtils.mkdir_p gorgon_dir_path
    Dir.chdir gorgon_dir_path

    create_listener_config_file

    create_gorgon_service

    start_gorgon_daemon
  end

  private

  def gorgon_dir_path
    @gorgon_dir_path ||= "#{Dir.home}/#{GORGON_DIR}"
  end

  def create_listener_config_file
    worker_slots = worker_slots_prompt
    puts "Using #{worker_slots} worker slots"
    amqp_host = @configuration[:connection][:host]
    puts "Amqp host is '#{amqp_host}'"

    puts "Creating #{LISTENER_CONFIG_FILE} in #{Dir.pwd}"
    File.open(LISTENER_CONFIG_FILE, 'w') do |f|
      f.write listener_config(amqp_host, worker_slots)
    end
  end

  def create_gorgon_service
    params = {}
    params[:username] = Etc.getlogin
    params[:rvm_bin_path] = rvm_bin_path
    params[:gemset] = get_current_gemset

    tmp_gorgon_conf = '/tmp/gorgon.conf'
    File.open(tmp_gorgon_conf, 'w') do |f|
      f.write gorgon_conf(params)
    end

    puts "Creating '#{GORGON_INIT_FILE}'"

    system("sudo cp /tmp/gorgon.conf #{GORGON_INIT_FILE}")
  end

  def rvm_bin_path
    cmd = 'which rvm'
    path = get_shell_cmd_output cmd, "Error getting rvm path. Make sure '#{cmd}' works"
    puts "Using '#{path}'"
    path
  end

  def get_current_gemset
    return @gemset unless @gemset.nil?

    cmd = 'rvm current'
    @gemset = get_shell_cmd_output cmd, "Error getting current gem. Make sure '#{cmd}' works"
    puts "Using gemset '#{@gemset}'."
    @gemset
  end

  def get_shell_cmd_output cmd, error_message
    result = `#{cmd}`.strip
    if $?.exitstatus != 0
      $stderr.puts "#{error_message}"
      $stderr.puts "Aborting installation"
      exit
    end
    result
  end

  def start_gorgon_daemon
    system("sudo start gorgon")
  end

  def gem_available?(name)
    Gem::Specification.find_by_name(name)
  rescue Gem::LoadError
    false
  rescue
    Gem.available?(name)
  end

  def worker_slots_prompt
    begin
      puts "Number of worker slots (default #{DEFAULT_NO_WORKERS})?"
      input = $stdin.gets.chomp
      if input == ""
        worker_slots = DEFAULT_NO_WORKERS
        break
      end

      worker_slots = input.to_i
      if worker_slots <= 0 || worker_slots >= 20
        puts "Please, enter a valid number between 0 and 19"
      end
    end while worker_slots <= 0 || worker_slots >= 20
    worker_slots
  end

  def listener_config amqp_host, worker_slots
    <<-CONFIG
{
  "connection": {
    "host": "#{amqp_host}"
  },

  "worker_slots": #{worker_slots},
  "log_file": "/tmp/gorgon-remote.log"
}
CONFIG
  end

  def gorgon_conf params
    <<-CONF_FILE
description "Start gorgon listener"

start on filesystem or runlevel [2345]
stop on runlevel [!2345]

respawn
respawn limit 10 10

pre-start script

bash << "EOF"
  mkdir -p /var/log/gorgon
  chown -R #{params[:username]} /var/log/gorgon
EOF

end script

exec su - #{params[:username]} -c 'cd #{gorgon_dir_path} && #{params[:rvm_bin_path]} #{params[:gemset]} do gorgon listen >> /var/log/gorgon/gorgon.log 2>&1'
CONF_FILE
  end
end
