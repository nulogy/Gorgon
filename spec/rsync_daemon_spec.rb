require 'gorgon/rsync_daemon'

describe RsyncDaemon do
  before(:each) do
    Kernel.stub(:system => true)
    Dir.stub(:mktmpdir => "loltmpdir", :pwd => "/lol/hax")
    Dir.stub(:chdir).and_yield
    File.stub(:write => 100, :read => "12345")
    @r = RsyncDaemon.new
  end

  it "starts the rsync daemon" do
    Kernel.should_receive(:system).with("rsync --daemon --config rsyncd.conf")

    @r.start
  end

  it "creates a temporary directory for the configuration and pid files" do
    Dir.should_receive(:mktmpdir).with("gorgon").and_return("loltmpdir")
    Dir.should_receive(:chdir).with("loltmpdir")

    @r.start
  end

  it "writes the config file" do
    valid_config = <<-EOF
port = 43434
pid file = rsync.pid

[src]
  path = /lol/hax
  read only = true
  use chroot = false
EOF
    File.should_receive(:write).with("rsyncd.conf", valid_config)

    @r.start
  end

  it "reports when an error has prevented startup" do
    Kernel.should_receive(:system).and_return(false)

    @r.start.should == false
  end

  it "only starts once" do
    Kernel.should_receive(:system).once

    @r.start
    @r.start
  end

  it "stops the rsync daemon" do
    @r.start

    File.should_receive(:read).with("rsync.pid").and_return("12345")
    Kernel.should_receive(:system).with("kill 12345")

    @r.stop
  end

  it "only tries to stop if the daemon is started" do
    Kernel.should_not_receive(:system)

    @r.stop
  end

  it "can be restarted" do
    Kernel.should_receive(:system).exactly(3).times

    @r.start
    @r.stop
    @r.start
  end
end