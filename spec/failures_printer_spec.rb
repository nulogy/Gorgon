require 'gorgon/failures_printer'

describe FailuresPrinter do
  let(:job_state) { stub("Job State", :add_observer => nil,
                         :is_job_complete? => true, :is_job_cancelled? => false,
                         :each_failed_test => nil,
                         :each_running_file => nil)}
  let(:fd) {stub("File descriptor", :write => nil)}

  subject do
    FailuresPrinter.new(job_state)
  end

  it { should respond_to :update }

  describe "#initialize" do
    it "add its self to observers of job_state" do
      job_state.should_receive(:add_observer)
      FailuresPrinter.new job_state
    end
  end

  describe "#update" do
    before do
      @printer = FailuresPrinter.new job_state
    end

    context "job is not completed nor cancelled" do
      it "doesn't output anything" do
        job_state.stub!(:is_job_complete? => false)
        File.should_not_receive(:open)
        @printer.update({})
      end
    end

    context "job is completed" do
      it "outputs failed tests return by job_state#each_failed_test" do
        job_state.stub!(:each_failed_test).and_yield({:filename => "file1.rb"}).and_yield({:filename => "file2.rb"})
        File.should_receive(:open).with(FailuresPrinter::OUTPUT_FILE, 'w+').and_yield fd
        fd.should_receive(:write).with(Yajl::Encoder.encode(["file1.rb", "file2.rb"]))
        @printer.update({})
      end
    end

    context "job is cancelled" do
      before do
        job_state.stub!(:is_job_complete?).and_return(false)
        job_state.stub!(:is_job_cancelled?).and_return(true)
      end

      it "outputs failed tests return by job_state#each_failed_test" do
        job_state.stub!(:each_failed_test).and_yield({:filename => "file1.rb"}).and_yield({:filename => "file2.rb"})
        File.should_receive(:open).with(FailuresPrinter::OUTPUT_FILE, 'w+').and_yield fd
        fd.should_receive(:write).once.with(Yajl::Encoder.encode(["file1.rb", "file2.rb"]))
        @printer.update({})
      end

      it "outputs still-running files returns by job_state#each_running_file" do
        job_state.stub!(:each_running_file).and_yield("host1", "file1.rb").and_yield("host2", "file2.rb")
        File.stub!(:open).and_yield fd
        fd.should_receive(:write).once.with(Yajl::Encoder.encode(["file1.rb", "file2.rb"]))
        @printer.update({})
      end
    end
  end
end
