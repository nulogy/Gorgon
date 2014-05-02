require 'gorgon/rsync_daemon'

describe RsyncDaemon do
  let(:directory) {'/lol/hax'}

  before(:each) do
    Kernel.stub(:system => true)
    Dir.stub(:mkdir => nil)
    Dir.stub(:chdir).and_yield
    File.stub(:write => 100, :read => "12345", :directory? => true)
    FileUtils.stub(:remove_entry_secure => nil)
    @r = RsyncDaemon
  end

  it "starts the rsync daemon" do
    Kernel.should_receive(:system).with("rsync --daemon --config rsyncd.conf")

    @r.start(directory)
  end

  it "creates a directory in temporary dir for the configuration and pid files" do
    Dir.should_receive(:mkdir).with(RsyncDaemon::RSYNC_DIR_NAME)
    Dir.should_receive(:chdir).with(RsyncDaemon::RSYNC_DIR_NAME)

    @r.start(directory)
  end

  it "writes the config file" do
    valid_config = <<-EOF
port = 43434
pid file = rsync.pid

[src]
  path = /lol/hax
  read only = false
  use chroot = false
EOF
    File.should_receive(:write).with("rsyncd.conf", valid_config)

    @r.start(directory)
  end

  it "reports when an error has prevented startup" do
    Kernel.should_receive(:system).and_return(false)

    @r.start(directory).should == false
  end

  it "stops the rsync daemon" do
    @r.start(directory)

    File.should_receive(:read).with("rsync.pid").and_return("12345")
    Kernel.should_receive(:system).with("kill 12345")

    @r.stop
  end
end
