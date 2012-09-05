require 'gorgon/worker_spawner'

describe WorkerSpawner do
  let(:callback_handler) { stub("Callback Handler", :before_creating_workers => nil) }
  let(:params) {
    {
      :callback_handler => callback_handler
    }
  }

  describe '#spawn' do
    before do
      @spawner = WorkerSpawner.new params
      @spawner.stub!(:fork)

      WorkerSpawner.any_instance.stub(:configuration).and_return({:worker_slots => 2})
    end

    it "should call before_creating_workers callback" do
      callback_handler.should_receive(:before_creating_workers)

      @spawner.spawn 1
    end

    it "should fork n times" do
      @spawner = WorkerSpawner.new params

      @spawner.should_receive(:fork).twice
      @spawner.spawn 2
    end
  end
end
