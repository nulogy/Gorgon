require 'gorgon/command'

describe Gorgon::Command do
  context 'start' do
    it 'starts the test suite' do
      originator = double('originator')
      originator.should_receive(:originate).with(no_args).and_return(0)
      Originator.should_receive(:new).with(no_args).and_return(originator)
      begin
        Gorgon::Command.new([]).run!('start')
      rescue SystemExit => e
        error_code = e.status
      end

      error_code.should eq(0)
    end
  end

  context 'listen' do
    it 'starts listener' do
      listener = double('listener')
      listener.should_receive(:listen).with(no_args).and_return(true)
      Listener.should_receive(:new).with(no_args).and_return(listener)
      Gorgon::Command.new([]).run!('listen')
    end
  end

  context 'start rsync' do
    it 'starts rsync for directory' do
      RsyncDaemon.should_receive(:start).with('/path/to/directory').and_return(true)
      Gorgon::Command.new(['/path/to/directory']).run!('start_rsync')
    end

    it 'exits with failure if rsync does not start' do
      RsyncDaemon.should_receive(:start).with(nil).and_return(false)
      begin
        Gorgon::Command.new([]).run!('start_rsync')
      rescue SystemExit => e
        error_code = e.status
      end

      error_code.should eq(1)
    end
  end

  context 'stop rsync' do
    it 'stops rsync daemon' do
      RsyncDaemon.should_receive(:stop).with(no_args).and_return(true)
      Gorgon::Command.new([]).run!('stop_rsync')
    end

    it 'exits with failure if rsync does not stop' do
      RsyncDaemon.should_receive(:stop).with(no_args).and_return(false)
      begin
        Gorgon::Command.new([]).run!('stop_rsync')
      rescue SystemExit => e
        error_code = e.status
      end

      error_code.should eq(1)
    end
  end

  context 'manage workers' do
    it 'starts worker manager' do
      manager = double('manager')
      ENV['GORGON_CONFIG_PATH'] = '/path/to/config'
      WorkerManager.should_receive(:build).with('/path/to/config').and_return(manager)
      manager.should_receive(:manage).with(no_args).and_return(true)

      begin
        Gorgon::Command.new([]).run!('manage_workers')
      rescue SystemExit
      end
      ENV.delete('GORGON_CONFIG_PATH')
    end
  end

  context 'ping' do
    it 'pings the listeners' do
      ping_service = double('ping service')
      PingService.should_receive(:new).with(no_args).and_return(ping_service)
      ping_service.should_receive(:ping_listeners).with(no_args).and_return(true)

      Gorgon::Command.new([]).run!('ping')
    end
  end

  context 'init' do
    it 'creates initial files for provided framework' do
      Settings::InitialFilesCreator.should_receive(:run).with('rails').and_return(true)

      Gorgon::Command.new(['rails']).run!('init')
    end
  end

  context 'install listener' do
    it 'run listener' do
      ListenerInstaller.should_receive(:install).with(no_args).and_return(true)

      Gorgon::Command.new([]).run!('install_listener')
    end
  end

  context 'gem' do
    it 'passes arguments to gem command' do
      gem_service = double('gem service')
      opts = ['install', 'bunny', '--version', '2.0.0']
      gem_service.should_receive(:run).with(opts.join(' ')).and_return(true)
      GemService.should_receive(:new).with(no_args).and_return(gem_service)

      Gorgon::Command.new(opts).run!('gem')
    end
  end
end
