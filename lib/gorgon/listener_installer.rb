class ListenerInstaller
  GORGON_DIR=".gorgon"
  DEFAULT_NO_WORKERS = 4
  LISTENER_CONFIG_FILE = "gorgon_listener.json"
  FOREMAN_CONFIG_FILE = "Procfile"

  class << self
    include Configuration

    def install
      @@configuration = load_configuration_from_file("gorgon.json")

      Dir.chdir Dir.home
      Dir.mkdir GORGON_DIR unless Dir.exists? GORGON_DIR
      Dir.chdir GORGON_DIR

      install_gem "gorgon"

      install_gem "foreman"

      create_listener_config_file
      create_foreman_config_file

      foreman_export_to_upstart

      start_gorgon_daemon

      run_gorgon_on_system_start
    end

    private

    def install_gem gem
      system("gem install #{gem}") unless gem_available? gem
      if $?.exitstatus != 0
        puts "Error installing #{gem} gem. Aborting installation"
        exit
      end
    end

    def create_listener_config_file
      worker_slots = worker_slots_prompt
      puts "Using #{worker_slots} worker slots"
      amqp_host = @@configuration[:connection][:host]
      puts "Amqp host is '#{amqp_host}'"

      puts "Creating #{LISTENER_CONFIG_FILE} in #{Dir.pwd}"
      File.open(LISTENER_CONFIG_FILE, 'w') do |f|
        f.write listener_config(amqp_host, worker_slots)
      end
    end

    def create_foreman_config_file
      File.open(FOREMAN_CONFIG_FILE, 'w') do |f|
        f.write "listener: [[ -s \"$HOME/.rvm/scripts/rvm\" ]] && source \"$HOME/.rvm/scripts/rvm\" && rvm use 1.9.3 && gorgon listen > listener.out 2> listener.err"
      end
    end

    def foreman_export_to_upstart
      system("rvmsudo foreman export upstart /etc/init -a gorgon -u `whoami` -c listener=1")
    end

    def start_gorgon_daemon
      system("sudo start gorgon")
    end

    def run_gorgon_on_system_start
      gorgon_init_file = '/etc/init/gorgon.conf'
      start_on_init_cmd = 'start on runlevel [2345]'

      File.open(gorgon_init_file, "r+") do |f|
        lines = f.readlines
      end

      lines = [start_on_init_cmd] + lines

      File.new(gorgon_init_file, "w") do |output|
        lines.each { |line| output.write line }
      end
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
  end
end
