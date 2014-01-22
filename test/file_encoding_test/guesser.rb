# encoding: UTF-8
require 'file_encoding/guesser'

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
  include FileEncoding

  def setup
    @guesser = Guesser.new(&-> { nil })
  end

  def test_exposes_available_method_always_false
    assert_respond_to @guesser, :available?
    refute            @guesser.available?
  end

  def test_exposes_guess_method_always_nil
    assert_respond_to @guesser, :guess
    assert_nil        @guesser.guess(__FILE__)
  end
end

class TestRubyGuesser < Minitest::Test
  include FileEncoding

  def setup
    @block   = ->(input) { Guess.new(__ENCODING__, 1.0) }
    @noop    = ->(input) { nil }
    @invalid = ->(input) { input }
  end

  def test_exposes_requirements_reader
    guesser = RubyGuesser.new(true, &@block)
    assert_respond_to guesser, :requirements
    refute_respond_to guesser, :requirements=
  end

  def test_new_guess_raises_error_if_no_block_set
    assert_raises(ArgumentError) { RubyGuesser.new(true) }
  end

  def test_available_on_correct_ruby_version
    this_ruby = RUBY_VERSION
    next_ruby = this_ruby.split('.').map {|e| Integer(e) + 1 }.join('.')
    assert RubyGuesser.new({ruby: ">= #{this_ruby}"}, &@block).available?
    refute RubyGuesser.new({ruby: ">= #{next_ruby}"}, &@block).available?
  end

  def test_available_when_correct_gem_version_available
    # note this is dependent on the Gemfile config
    assert RubyGuesser.new({minitest: '>= 5.0'}, &@block).available?
    refute RubyGuesser.new({minitest: '<= 4.0'}, &@block).available?
  end

  def test_available_if_callable_test_passes
    assert RubyGuesser.new(-> { true },  &@block).available?
    refute RubyGuesser.new(-> { false }, &@block).available?
  end

  def test_available_if_scalar_is_true
    assert RubyGuesser.new(true,  &@block).available?
    refute RubyGuesser.new(false, &@block).available?
  end

  def test_avaialble_if_all_requirements_are_met
    reqs = {ruby: ">= #{RUBY_VERSION}", minitest: '>= 5.0'}
    assert RubyGuesser.new(reqs, true,  &@block).available?
    refute RubyGuesser.new(reqs, false, &@block).available?
  end

  def test_available_raises_error_if_requirement_is_invalid
    assert_raises(RuntimeError) { RubyGuesser.new('Foobar', &@noop).guess(__FILE__) }
  end

  def test_guess_returns_a_guess_or_nil
    assert_instance_of Guess, RubyGuesser.new(true, &@block).guess(__FILE__)
    assert_nil         RubyGuesser.new(true, &@noop).guess(__FILE__)
  end

  def test_guess_raises_error_if_block_return_invalid
    assert_raises(TypeError) { ShellGuesser.new(@tool, &@invalid).guess(__FILE__) }
  end
end

class TestShellGuesser < Minitest::Test
  include FileEncoding

  def setup
    @tool    = 'pwd'
    @args    = ['-P']
    @output  = %x{#{@tool} #{@args.join(' ')}}.chomp
    @block   = ->(input) { Guess.new(input, 1.0) }
    @noop    = ->(input) { nil }
    @invalid = ->(input) { input }
    @guesser = ShellGuesser.new(@tool, *@args, &@block)
  end

  def test_new_raises_error_if_no_block_set
    assert_raises(ArgumentError) { ShellGuesser.new(@tool) }
  end

  def test_exposes_tool_reader
    assert_respond_to @guesser, :tool
    refute_respond_to @guesser, :tool=
    assert_equal      @tool, @guesser.tool
  end

  def test_exposes_args_reader
    assert_respond_to @guesser, :args
    refute_respond_to @guesser, :args=
    assert_equal      @args, @guesser.args
  end

  def test_exposes_sh_reader
    assert_respond_to  @guesser, :sh
    refute_respond_to  @guesser, :sh=
    assert_instance_of ShellRunner, @guesser.sh
  end

  def test_available_if_tool_is_found
    assert_equal (File.file?(@tool) || !%x{which #{@tool}}.empty?), @guesser.available?
    refute       ShellGuesser.new('-', &@block).available?
  end

  def test_guess_returns_a_guess_or_nil
    assert_instance_of Guess, @guesser.guess(__FILE__)
    assert_nil         ShellGuesser.new(@tool, &@noop).guess(__FILE__)
  end

  def test_guess_raises_error_if_block_return_invalid
    assert_raises(TypeError) { ShellGuesser.new(@tool, &@invalid).guess(__FILE__) }
  end
end

class TestByteGuesser < Minitest::Test
  include FileEncoding

  def setup
    @chunk_size = 20
    @block      = ->(byte_set) { Guess.new(byte_set.file.path, byte_set.chunk_size) }
    @noop       = ->(input)    { nil }
    @invalid    = ->(input)    { input }
    @reference  = ByteSet.new(__FILE__, @chunk_size)
    @guesser    = ByteGuesser.new(@chunk_size, &@block)
  end

  def test_new_raises_error_if_no_block_set
    assert_raises(ArgumentError) { ByteGuesser.new }
  end

  def test_new_raises_error_if_chunk_size_invalid
    assert_raises(ArgumentError) { ByteGuesser.new('foobar') }
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

  def test_guess_returns_a_guess_or_nil
    assert_instance_of Guess, @guesser.guess(__FILE__)
    assert_nil         ByteGuesser.new(&@noop).guess(__FILE__)
  end

  def test_guess_respects_chunk_size
    # Guess#confidence == ByteSet#chunk_size (set by @block)
    assert_equal @chunk_size, @guesser.guess(__FILE__).confidence
    refute_equal @chunk_size, ByteGuesser.new(&@block).guess(__FILE__).confidence
  end

  def test_guess_raises_error_if_block_return_invalid
    assert_raises(TypeError) { ShellGuesser.new(@tool, &@invalid).guess(__FILE__) }
  end
end
