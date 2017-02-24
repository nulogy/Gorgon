require 'gorgon/command'
require File.expand_path("../support/stream_helpers", __FILE__)

describe Gorgon::Command do
  include Gorgon::StreamHelpers

  context "run command" do
    it "runs whitlisted command" do
      silence_streams($stdout) do
        Gorgon::Command::COMMAND_WHITELIST.each do |command|
          command_executioner = Gorgon::Command.new([command])
          command_executioner.should_receive(command).with(no_args).and_return(true)
          command_executioner.run_command
        end
      end
    end

    it "prints error message for non-whitelisted command" do
      command_executioner = Gorgon::Command.new(['non-existing'])
      command_executioner.should_receive(:write_error_message).with('non-existing').and_return(true)
      command_executioner.run_command
    end
  end

  shared_examples_for "start" do
    describe "start" do
      it 'starts the test suite' do
        originator = double('originator')
        originator.should_receive(:originate).with(no_args).and_return(0)
        Originator.should_receive(:new).with(no_args).and_return(originator)
        silence_streams($stdout) do
          begin
            Gorgon::Command.run(argv)
          rescue SystemExit => e
            error_code = e.status
          end
          error_code.should eq(0)
        end
      end
    end
  end

  context 'start' do
    context "with start command" do
      it_should_behave_like "start" do
        let(:argv) { ['start'] }
      end
    end

    context "without any command" do
      it_should_behave_like "start" do
        let(:argv) { [] }
      end
    end
  end

  context 'listen' do
    it 'starts listener' do
      listener = double('listener')
      listener.should_receive(:listen).with(no_args).and_return(true)
      Listener.should_receive(:new).with(no_args).and_return(listener)
      silence_streams($stdout) do
        Gorgon::Command.run(['listen'])
      end
    end
  end

  context 'start rsync' do
    it 'starts rsync for directory' do
      silence_streams($stdout) do
        RsyncDaemon.should_receive(:start).with('/path/to/directory').and_return(true)
        Gorgon::Command.run(['start_rsync', '/path/to/directory'])
      end
    end

    it 'exits with failure if rsync does not start' do
      RsyncDaemon.should_receive(:start).with(nil).and_return(false)
      silence_streams($stdout) do
        begin
          Gorgon::Command.run(['start_rsync'])
        rescue SystemExit => e
          error_code = e.status
        end

        error_code.should eq(1)
      end
    end
  end

  context 'stop rsync' do
    it 'stops rsync daemon' do
      RsyncDaemon.should_receive(:stop).with(no_args).and_return(true)
      silence_streams($stdout) do
        Gorgon::Command.run(['stop_rsync'])
      end
    end

    it 'exits with failure if rsync does not stop' do
      RsyncDaemon.should_receive(:stop).with(no_args).and_return(false)
      silence_streams($stdout) do
        begin
          Gorgon::Command.run(['stop_rsync'])
        rescue SystemExit => e
          error_code = e.status
        end
        error_code.should eq(1)
      end
    end
  end

  context 'manage workers' do
    it 'starts worker manager' do
      manager = double('manager')
      ENV['GORGON_CONFIG_PATH'] = '/path/to/config'
      WorkerManager.should_receive(:build).with('/path/to/config').and_return(manager)
      manager.should_receive(:manage).with(no_args).and_return(true)

      silence_streams($stdout) do
        begin
          Gorgon::Command.run(['manage_workers'])
        rescue SystemExit
        end
      end
      ENV.delete('GORGON_CONFIG_PATH')
    end
  end

  context 'ping' do
    it 'pings the listeners' do
      ping_service = double('ping service')
      PingService.should_receive(:new).with(no_args).and_return(ping_service)
      ping_service.should_receive(:ping_listeners).with(no_args).and_return(true)

      silence_streams($stdout) do
        Gorgon::Command.run(['ping'])
      end
    end
  end

  context 'init' do
    it 'creates initial files for provided framework' do
      Settings::InitialFilesCreator.should_receive(:run).with('rails').and_return(true)

      silence_streams($stdout) do
        Gorgon::Command.run(['init', 'rails'])
      end
    end
  end

  context 'install listener' do
    it 'run listener' do
      ListenerInstaller.should_receive(:install).with(no_args).and_return(true)

      silence_streams($stdout) do
        Gorgon::Command.run(['install_listener'])
      end
    end
  end

  context 'gem' do
    it 'passes arguments to gem command' do
      gem_service = double('gem service')
      opts = ['install', 'bunny', '--version', '2.0.0']
      gem_service.should_receive(:run).with(opts.join(' ')).and_return(true)
      GemService.should_receive(:new).with(no_args).and_return(gem_service)

      silence_streams($stdout) do
        Gorgon::Command.run(opts.unshift('gem'))
      end
    end
  end
end
