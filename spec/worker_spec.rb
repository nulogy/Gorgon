require 'gorgon/worker'

class FakeAmqp
  def initialize mock_queue, mock_exchange
    @mock_queue = mock_queue
    @mock_exchange = mock_exchange
  end

  def start_worker queue_name, exchange_name
    yield @mock_queue, @mock_exchange
  end
end

describe Worker do
  describe '#work' do
    it 'should do nothing if the file queue is empty' do
      mock_queue = stub(:pop => nil)
      fake_amqp = FakeAmqp.new mock_queue, double
      worker = Worker.new fake_amqp, 'queue', 'exchange'
      
      worker.work
    end
  end
  
end
