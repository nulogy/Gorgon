require "rubygems"
require 'gorgon'
require 'gorgon/originator'
require 'gorgon/listener'
require 'gorgon/rsync_daemon'
require 'gorgon/worker_manager'
require 'gorgon/ping_service'
require 'gorgon/gem_service'
require 'gorgon/version'
require 'gorgon/listener_installer'
require 'gorgon/settings/initial_files_creator'

module Gorgon
  class Command
    attr_reader :argv
    WELCOME_MESSAGE = "Welcome to Gorgon #{Gorgon::VERSION}"
    USAGE = <<-EOT
USAGE: gorgon <command> [<args>]

COMMANDS:
  start                       remotely run all tests specified in gorgon.json
  listen                      start a listener process using the settings in gorgon_listener.json
  ping                        ping listeners and show hosts and gorgon's version they are running
  init [<framework>]          create initial files for current project
  install_listener            run gorgon listener as a daemon process
  start_rsync <directory>     start rsync daemon. Run this command in File Server
  stop_rsync                  stop rsync daemon.
  manage_workers
  gem command [<options>...]  execute the gem command on every listener and shutdown listener.
                              (e.g. 'gorgon gem install bunny --version 1.0.0')

OPTIONS:
  -h, --help       print this message
  -v, --version    print gorgon version
    EOT

    COMMAND_WHITELIST = %w(help version start listen start_rsync stop_rsync manage_workers ping gem init install_listener)

    def initialize(argv)
      @argv = argv
    end

    def run!(command)
      command = parse(command)
      if COMMAND_WHITELIST.include?(command)
        puts WELCOME_MESSAGE unless ['version', 'help'].include?(command)
        send(command)
      else
        write_error_message(command)
      end
    end

    def help
      write_usage
      exit(0)
    end

    def version
      puts Gorgon::VERSION
      exit(0)
    end

    def start
      o = Originator.new
      exit o.originate
    end

    def listen
      l = Listener.new
      l.listen
    end

    def start_rsync
      puts "Starting rsync daemon..."
      directory = argv[0]
      exit 1 unless RsyncDaemon.start directory
      puts "Rsync Daemon is running. Use 'gorgon stop_rsync' to kill it."
    end

    def stop_rsync
      puts "Stopping rsync daemon..."
      exit 1 unless RsyncDaemon.stop
      puts "Done"
    end

    def manage_workers
      config_path = ENV["GORGON_CONFIG_PATH"]

      manager = WorkerManager.build config_path
      manager.manage

      # For some reason I have to 'exit' here, otherwise WorkerManager process crashes
      exit
    end

    def ping
      PingService.new.ping_listeners
    end

    def gem
      gem_opts = argv.join(" ")
      GemService.new.run(gem_opts)
    end

    def init
      framework = argv[0]
      Settings::InitialFilesCreator.run(framework)
    end

    def install_listener
      ListenerInstaller.install
    end

    private

    def write_usage
      puts USAGE
    end

    def parse(command)
      case command
      when '--version', '-v'
        'version'
      when 'help', '--help', '-h'
        'help'
      else
        command
      end
    end

    def write_error_message(command)
      puts "Error: Command '#{command}' not recognized"
      write_usage
      exit(1)
    end
  end
end
