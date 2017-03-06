require 'gorgon/originator_protocol'
require 'gorgon/originator_logger'
require 'gorgon/configuration'

module Gorgon
  class GemService
    include Configuration

    TIMEOUT = 3

    def initialize
      @configuration = load_configuration_from_file("gorgon.json", merge: "gorgon_secret.json")
      @logger = OriginatorLogger.new @configuration[:originator_log_file]
      @protocol = OriginatorProtocol.new @logger
      @hosts_running = []
      @started_running = 0
      @finished_running = 0
    end

    def run command
      EM.run do
        @logger.log "Connecting..."
        @protocol.connect @configuration[:connection],  :on_closed => proc {EM.stop}

        @logger.log "Sending gem command #{command}..."
        @protocol.send_message_to_listeners :gem_command, :gem_command => command

        @protocol.receive_payloads do |payload|
          @logger.log "Received #{payload}"

          handle_reply(Yajl::Parser.new(:symbolize_keys => true).parse(payload))
        end

        EM.add_periodic_timer(TIMEOUT) { disconnect_if_none_running }
      end
    end

    private

    def disconnect_if_none_running
      disconnect if @hosts_running.empty?
    end

    def handle_reply payload
      hostname = payload[:hostname].colorize(Colors::HOST)
      command = payload[:command].colorize(Colors::COMMAND) if payload[:command]

      case payload[:type]
      when "running_command"
        puts "#{hostname} is running command #{payload[:command]}..."
        @hosts_running << payload[:hostname]
        @started_running += 1
      when "command_completed"
        puts "Command '#{command}' completed in #{hostname}"
        command_finished payload
      when "command_failed"
        puts "Command '#{command}' failed in #{hostname}."
        command_finished payload
      else
        puts "Unknown message received: #{payload}"
      end
    end

    def command_finished payload
      puts "Output:\n#{payload[:stdout]}#{payload[:stderr]}"
      @hosts_running.delete payload[:hostname]
      @finished_running += 1
    end

    def disconnect
      @protocol.disconnect
      print_summary
    end

    def print_summary
      puts "#{@started_running} host(s) started running the command. #{@finished_running} host(s) reported they finished"
      puts "Use 'gorgon ping' to check if all listeners are running the correct gorgon version."
    end
  end
end
