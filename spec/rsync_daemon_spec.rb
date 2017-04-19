require 'gorgon/rsync_daemon'

describe Gorgon::RsyncDaemon do
  let(:directory) {'/lol/hax'}

  before(:each) do
    allow(Kernel).to receive(:system).and_return(true)
    allow(Dir).to receive(:mkdir).and_return(nil)
    allow(Dir).to receive(:chdir).and_yield
    allow(File).to receive(:write).and_return(100)
    allow(File).to receive(:read).and_return("12345")
    allow(File).to receive(:directory?).and_return(true)
    allow(FileUtils).to receive(:remove_entry_secure).and_return(nil)
    allow(TCPServer).to receive(:new).and_return(double('TCPServer', :close => nil))
    @r = Gorgon::RsyncDaemon
  end

  it "starts the rsync daemon" do
    allow(Kernel).to receive(:system).with("rsync --daemon --config rsyncd.conf")

    @r.start(directory)
  end

  it "creates a directory in temporary dir for the configuration and pid files" do
    expect(Dir).to receive(:mkdir).with(Gorgon::RsyncDaemon::RSYNC_DIR_NAME)
    expect(Dir).to receive(:chdir).with(Gorgon::RsyncDaemon::RSYNC_DIR_NAME)

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
    expect(File).to receive(:write).with("rsyncd.conf", valid_config)

    @r.start(directory)
  end

  it "reports when an error has prevented startup" do
    expect(Kernel).to receive(:system).and_return(false)

    expect(@r.start(directory)).to be_falsey
  end

  it "stops the rsync daemon" do
    @r.start(directory)

    expect(File).to receive(:read).with("rsync.pid").and_return("12345")
    expect(Kernel).to receive(:system).with("kill 12345")

    @r.stop
  end
end
