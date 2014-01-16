# encoding: UTF-8
require 'file_encoding/byte_set'
require 'semver'
require 'shellrun'

# Encoding guesser foundation library.
# @author Martin Kopischke
# @version {FileEncoding::VERSION}
module FileEncoding
  # Guess PORO, internal usage only.
  Guess = Struct.new(:encoding, :confidence)
  private_constant :Guess

  # @abstract
  # Guesser base class.
  class Guesser
    # Check if #guess can return a result.
    # @return false.
    def available?
      false
    end

    # Guess a file’s encoding.
    # @param file [File, String] the file whose encoding should be guessed.
    # @return nil.
    def guess(file)
      validate_result(nil)
    end

    private
    # Make sure either a Guess object is returned or nil.
    def validate_result(guess)
      guess if guess.is_a?(Guess)
    end
  end

  # Guess encoding using a Ruby test block.
  class RubyGuesser < Guesser
    # @param minimum_version [String, Float, Integer, SemanticVersion]
    #   minimum Ruby version for the guesser.
    # @param test [Proc] test block to run on the file.
    def initialize(minimum_version, &test)
      @version = SemanticVersion.new(minimum_version)
      @test    = test || ->(_) { nil }
    end

    # @return [true] if the current Ruby version is greater or equal the minimum version.
    # @return [false] if the current Ruby version is less than the minimum version.
    def available?
      @version <= RUBY_VERSION
    end

    # Call the defined test block on `file`.
    # @param (see Guesser#guess)
    # @return [FileEncoding::Guess] if the test block returned a guess.
    # @return [nil] if the test block returned anything but a guess.
    def guess(file)
      validate_result(instance_exec(file, &@test))
    end
  end

  # Guess encoding using a shell call.
  class ShellGuesser < Guesser
    # @return [String] the shell tool to invoke when guessing.
    attr_reader :tool

    # @return [Array] the arguments to pass to #tool.
    attr_reader :args

    # @return [ShellRunner] the ShellRunner instance used for shell invocations.
    attr_reader :sh

    # @param tool [String] the shell tool to invoke when guessing.
    # @param tool_args [Array<String>] the arguments to pass to #tool.
    # @param process [Proc] the block to call on the output of the shell invocation.
    def initialize(tool, *tool_args, &process)
      @sh      = ShellRunner.new
      @tool    = tool
      @args    = tool_args
      @process = process || ->(_) { nil }
    end

    # @return [true] if `tool` is either found by absolute path, or in the shell $PATH.
    # @return [false] if `tool` is neither found by absolute path, nor in the shell $PATH.
    def available?
      File.file?(@tool) || !@sh.run_command('which', @tool).empty?
    end

    # Invoke #tool with #args on `file`, applying the processor block if given.
    # @param (see Guesser#guess)
    # @return [FileEncoding::Guess] if the test block returned a guess.
    # @return [nil] if the test block returned anything but a guess.
    def guess(file)
      path   = File.expand_path(file.is_a?(File) ? file.path : file)
      output = @sh.run_command(@tool, *@args, path.shellescape, :'2>/dev/null')
      validate_result(instance_exec(output, &@process)) if @sh.ok?
    end
  end

  # Guess encoding by analyzing the byte structure.
  class ByteGuesser < Guesser
    attr_reader :chunk_size

    # @param chunk_size [Integer] the chunk size of the ByteSet created.
    # @param test [Proc] the test block to call on the created ByteSet.
    def initialize(chunk_size = nil, &test)
      @chunk_size = chunk_size
      @test       = test || ->(_) { nil }
    end

    # @return [true] if File.getbyte exists.
    # @return [false] if File.getbyte does not exist.
    def available?
      File.instance_methods.include?(:getbyte)
    end

    # Invoke the test block on a ByteSet of `file`.
    # @param file (see Guesser#guess)
    # @param byte_set [FileEncoding::ByteSet] a cached ByteSet for `file` (optional).
    # @note the `byte_set` argument  will be ignored if its file path or chunk size do not match `file` and #chunk_size.
    # @return [FileEncoding::Guess] if the test block returned a guess.
    # @return [nil] if the test block returned anything but a guess.
    def guess(file, byte_set = nil)
      if byte_set.nil? || byte_set.chunk_size != @chunk_size || File.expand_path(byte_set.file) != File.expand_path(file)
        byte_set = ByteSet.new(file, @chunk_size)
      end
      validate_result(instance_exec(byte_set, &@test))
    end
  end
end
