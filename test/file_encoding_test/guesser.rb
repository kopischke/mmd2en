# encoding: UTF-8
require 'file_encoding/guesser'
require 'semver'

class TestGuess < Minitest::Test
  include FileEncoding
  def setup
    @guess = Guess.new(Encoding::UTF_8, 1.0)
  end

  def test_exposes_encoding_and_confidence
    assert_respond_to @guess, :encoding
    assert_respond_to @guess, :confidence
  end
end

class TestGuesser < Minitest::Test
  def setup
    @guesser = FileEncoding::Guesser.new
  end

  def test_exposes_abstract_available_and_guess_methods
    assert_respond_to @guesser, :available?
    assert_respond_to @guesser, :guess
    refute     @guesser.available?
    assert_nil @guesser.guess(__FILE__)
  end
end

class TestRubyGuesser < Minitest::Test
  include FileEncoding
  def setup
    @action  = ->(input) { Guess.new(input, 1.0) }
    @guesser = FileEncoding::RubyGuesser.new(RUBY_VERSION, &@action)
  end

  def test_available_on_correct_ruby_version
    current = SemanticVersion.new(RUBY_VERSION)
    newer   = [current.major, current.minor + 1, current.patch].join('.')

    assert @guesser.available?
    assert FileEncoding::RubyGuesser.new(0.1).available?
    refute FileEncoding::RubyGuesser.new(newer).available?
  end

  def test_guess_returns_a_guess_if_block_passed
    assert_instance_of Guess, @guesser.guess(__FILE__)
    assert_equal @action.call(__FILE__), @guesser.guess(__FILE__)
    assert_nil  FileEncoding::RubyGuesser.new(RUBY_VERSION).guess(__FILE__)
  end
end

class TestShellGuesser < Minitest::Test
  include FileEncoding
  def setup
    @tool    = 'pwd'
    @args    = ['-P']
    @output  = %x{#{@tool} #{@args.join(' ')}}.chomp
    @block   = ->(input) { Guess.new(input, 1.0) }
    @guesser = FileEncoding::ShellGuesser.new(@tool, *@args, &@block)
  end

  def test_exposes_tool_reader
    assert_respond_to @guesser, :tool
    refute_respond_to @guesser, :tool=
    assert_equal @tool, @guesser.tool
  end

  def test_exposes_args_reader
    assert_respond_to @guesser, :args
    refute_respond_to @guesser, :args=
    assert_equal @args, @guesser.args
  end

  def test_exposes_sh_reader
    assert_respond_to @guesser, :sh
    refute_respond_to @guesser, :sh=
    assert_instance_of ShellRunner, @guesser.sh
  end

  def test_available_if_tool_is_found
    assert_equal (File.file?(@tool) || !%x{which #{@tool}}.empty?), @guesser.available?
    refute FileEncoding::ShellGuesser.new('-').available?
  end

  def test_guess_returns_a_guess_if_block_passed
    assert_instance_of Guess, @guesser.guess(__FILE__)
    assert_equal @block.call(@output), @guesser.guess(__FILE__)
    assert_nil  FileEncoding::ShellGuesser.new(@tool).guess(__FILE__)
  end
end

class TestByteGuesser < Minitest::Test
  include FileEncoding
  def setup
    @chunk_size = 20
    @block      = ->(byte_set) { Guess.new(byte_set.file.path, byte_set.chunk_size) }
    @reference  = FileEncoding::ByteSet.new(__FILE__, @chunk_size)
    @guesser    = FileEncoding::ByteGuesser.new(@chunk_size, &@block)
  end

  def test_exposes_chunk_size_reader
    assert_respond_to @guesser, :chunk_size
    refute_respond_to @guesser, :chunk_size=
    assert_equal   @chunk_size, @guesser.chunk_size
  end

  def test_available_if_getbyte_is_available
    File.stub(:instance_methods, [:getbyte]) do assert @guesser.available? end
    File.stub(:instance_methods, [])         do refute @guesser.available? end
  end

  def test_guess_returns_a_guess_if_block_passed
    assert_instance_of Guess, @guesser.guess(__FILE__)
    assert_equal @block.call(@reference), @guesser.guess(__FILE__)
    assert_nil FileEncoding::ByteGuesser.new.guess(__FILE__)
  end

  def test_guess_respects_chunk_size
    # Guess#confidence == ByteSet#chunk_size (set by @block)
    assert_equal @chunk_size, @guesser.guess(__FILE__).confidence
    refute_equal @chunk_size, FileEncoding::ByteGuesser.new(&@block).guess(__FILE__, @reference).confidence
  end

  def test_guess_uses_cached_byteset
    mock_bs = Minitest::Mock.new
    FileEncoding.stub_const(:ByteSet, mock_bs) do
      2.times do @guesser.guess(__FILE__, @reference) end
    end
    mock_bs.verify # no calls to ByteSet.new
  end

  def test_guess_ignores_cached_byteset_if_not_matching
    other_path    = Dir.glob(File.join(File.dirname(File.expand_path(__FILE__)), '..', '*.rb')).first
    other_file    = FileEncoding::ByteSet.new(other_path, @chunk_size)
    no_chunk_size = FileEncoding::ByteSet.new(__FILE__)
    refute_equal @block.call(other_file),    @guesser.guess(__FILE__, other_file)
    refute_equal @block.call(no_chunk_size), @guesser.guess(__FILE__, no_chunk_size)
  end
end
