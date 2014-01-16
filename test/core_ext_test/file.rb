# encoding: UTF-8
require 'core_ext/file'
require 'file_encoding/guesser'
require 'file_encoding/guessers'
require 'pathname'

class TestFile < Minitest::Test
  include FileEncoding

  def setup
    path   = Pathname.new(__FILE__).relative_path_from(Pathname.new(Dir.pwd)).to_s if File.expand_path(__FILE__) == __FILE__
    path ||= __FILE__
    @file  = File.new(path)
  end

  def teardown
    @file.close
  end

  def test_exposes_guess_encoding_methods
    assert_respond_to File,  :guess_encoding
    assert_respond_to @file, :guess_encoding
  end

  def test_guess_encoding_uses_encoding_guesser_queue
    base_set = [Guessers::Cheap::CORE_BOM, Guessers::Platform::FILE, Guessers::Platform::APPLE_XATTR]
    [Guessers.default_set, base_set].each do |set|
      queue = GuesserQueue.new(*set)
      GuesserQueue.stub(:new, queue) do
        @file.guess_encoding
      end
      assert_equal set.count, queue.count
      set.each.with_index do |g,i| assert_equal g, queue[i] end
    end
  end

  def test_encoding_passes_guess_options
    options    = {accept_dummy: rand(2) >= 1, stop_threshold: rand(100).to_f / 100, reject_threshold: rand(100).to_f / 100}
    guessers   = Guessers.default_set
    real_queue = GuesserQueue.new(*guessers)
    mock_queue = Minitest::Mock.new
    mock_queue.expect(:new, real_queue, [*guessers, options])
    FileEncoding.stub_const(:GuesserQueue, mock_queue) do
      @file.guess_encoding(**options)
    end
    mock_queue.verify
  end

  def test_exposes_expanded_path_method
    assert_respond_to @file, :expanded_path
  end

  def test_expanded_path_returns_expanded_creation_path
    assert_equal File.expand_path(@file.path), @file.expanded_path
  end
end
