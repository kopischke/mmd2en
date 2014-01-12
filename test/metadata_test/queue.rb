# encoding: UTF-8
require 'metadata/queue'
require 'tempfile'

class TestProcessorQueue < Minitest::Test
  def setup
    @queue = Metadata::ProcessorQueue.new
  end

  def test_initializes_empty
    assert_equal 0, @queue.count
  end

  def test_queues_and_dequeues_items
    count = rand(3..30)
    assert_equal true, @queue.empty?
    assert_equal 0, @queue.count

    count.times do rand(2) == 0 ? @queue << nil : @queue.push(nil) end
    assert_equal false, @queue.empty?
    assert_equal count, @queue.count

    count.times do @queue.pop end
    assert_equal true, @queue.empty?
    assert_equal 0, @queue.count
  end

  def test_exposes_item_accessor
    rand(3..30).times do |i|
      item = rand(0..1000)
      @queue << item
      assert_equal item, @queue[i]
    end
  end

  def test_is_enumerable
    count = rand(3..30)
    count.times do @queue << 0 end
    @queue.each_index do |i, _| assert_operator i, :<=, @queue.count end
    @queue.each do |v| assert_equal 0, v end
  end

  def test_compiles_metadata_from_all_processors_in_order
    Tempfile.open('TestProcessorQueue') do |file|
      proc_1 = Minitest::Mock.new
      proc_1.expect :call, {Title: 'My Title', KeyWords: ['foo', 'bar']}, [Tempfile]
      @queue << proc_1

      proc_2 = Minitest::Mock.new
      proc_2.expect :call, {'book' => 'My Book', 'title' => 'Alternate title', 'author' => 'Qi-Gong Jin'}, [Tempfile]
      @queue << proc_2

      timestamp = DateTime.now
      proc_3 = Minitest::Mock.new
      proc_3.expect :call, {'KEYWORDS' => ['baz', 'qux'], 'PUBLICATION DATE' => timestamp, author: 'Obi-Wan'}, [Tempfile]
      @queue << proc_3

      metadata = @queue.compile(file)
      assert_equal 5, metadata.count
      assert_equal 'Alternate title', metadata['title']
      assert_equal ['baz', 'qux'],    metadata['keywords']
      assert_equal 'My Book',         metadata['book']
      assert_equal 'Obi-Wan',         metadata['author']
      assert_equal timestamp,         metadata['publication date']

      proc_1.verify
      proc_2.verify
      proc_3.verify
    end
  end

  def test_warns_and_skips_processor_if_processor_error_raised
    err_msg = 'Blackboard Monitor Error'
    data_1  = {'foo' => 'bar'}
    data_2  = {'baz' => 'qux'}

    @queue << ->(_){ data_1 }
    @queue << ->(_){ raise err_msg }
    @queue << ->(_){ data_2 }

    Tempfile.open('TestProcessorQueue') do |file|
      assert_output('', err_msg << $/) {
        assert_equal data_1.merge(data_2), @queue.compile(file)
      }
    end
  end
end
