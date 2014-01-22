# encoding: UTF-8
require 'file_encoding/byte_set'
require 'shellrun'

# Encoding guesser foundation library.
# @author Martin Kopischke
# @version {FileEncoding::VERSION}
module FileEncoding
  # Guess PORO, internal usage only.
  Guess = Struct.new(:encoding, :confidence)

  # Guesser base class.
  #
  # Doesn’t on anything on its own (as {#available?} always returns `false`):
  # its constructor and guess methods are wrappers for its subclasses.
  class Guesser
    # Provides guesser block initialization and guards against missing blocks.
    # @note all instance variables are frozen to defend against modification
    #   through the guesser block (which runs in instance context).
    # @param block [Proc] the guesser block (will be run in instance context).
    # @raise [ArgumentError] if `block` is nil.
    def initialize(&block)
      @block = block or fail ArgumentError, "#{self.class} initialized without a guesser block!"
      instance_variables.each do |ivar| ivar.freeze end # defend against in-block manipulations.
    end

    # Check if #guess can return a result.
    # @return false.
    def available?
      false
    end

    # Provides conditional block evaluation and return value validation.
    # @param input [Object] the object to pass to the guesser block.
    # @return [FileEncoding::Guess, nil] if the return value of the guesser block is valid.
    # @raise [ArgumentError] if `@block` returns anything but nil or a {FileEncoding::Guess} object.
    # @raise [RuntimeError] if `@block` tries to modify instance variables.
    def guess(input)
      guess = available? ? instance_exec(input, &@block) : nil
      fail TypeError, "Invalid object type for block return: #{guess.class}!" unless guess.nil? || guess.is_a?(Guess)
      guess
    end
  end

  # Guess encoding using a Ruby test block.
  class RubyGuesser < Guesser
    # @return [Array<Hash, #call, Boolean>] the requirements to fulfill.
    attr_reader :requirements

    # @param requirements [Array<Hash, #call, Boolean>] the requirements to fulfill.
    #   Requirements interpretation depends on their type:
    #   * a Hash: if either the gem named like the Hash key, of Ruby itself if the key is 'ruby',
    #     are available (in the case of gems), meet the requirement(s) listed
    #     in the keyed Hash value (see Gem::Requirement for the format) and can be activated.
    #   * an object responding to `call`: the return value of calling the object.
    #   * a Boolean, or nil: the value.
    # @param (see Guesser#initialize)
    def initialize(*requirements, &block)
      @requirements = requirements
      super(&block)
    end

    # {include:Guesser#available?}
    # @return [Boolean] are all requirements for the test block met?
    # @raise [RuntimeError] if an invalid requirement is met.
    def available?
      @requirements.all? {|req|
        case
        when req.is_a?(Hash)
          req.all? {|target, requires|
            target   = String(target)
            requires = Array(requires)

            if target == 'ruby' # test Ruby version
              ruby_version = Gem::Version.new(RUBY_VERSION)
              requires.all? {|r| Gem::Requirement.create(r).satisfied_by?(ruby_version) }

            else # check for availability of matching gems
              specs    = Gem::Specification.find_all_by_name(target, *requires)
              return false if specs.empty?
              versions = specs.map(&:version)
              conflict = Gem::Specification.find_all_by_name(target).reject {|spec|
                  versions.include?(spec.version)
                }.find {|spec|
                  spec.activated?
                }
              specs.count > 0 && conflict.nil?
            end
          }
        when req.respond_to?(:call)           then req.call
        when [true, false, nil].include?(req) then req
        else fail RuntimeError, "'#{req}' is not a valid requirement!"
        end
      }
    end

    # Call the guesser block on `file`.
    # @param (see Guesser#guess)
    # @return (see Guesser#guess)
    def guess(file)
      super(file)
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
    # @param (see Guesser#initialize)
    def initialize(tool, *tool_args, &block)
      @sh      = ShellRunner.new
      @tool    = tool
      @args    = tool_args
      @process = block
      block    = Proc.new {|path|
          output = @sh.run_command(@tool, *@args, path, :'2>/dev/null')
          instance_exec(output, &@process) if @sh.ok?
        } if @process
      super(&block)
    end

    # {include:Guesser#available?}
    # @return [Boolean] is `tool` is either found by absolute path, or in the shell $PATH?
    def available?
      File.file?(@tool) || !@sh.run_command('which', @tool).empty?
    end

    # process the output of calling #tool with #args on the path of `file`.
    # @param (see Guesser#guess)
    # @return (see Guesser#guess)
    def guess(file)
      super(File.realpath(file))
    end
  end

  # Guess encoding by analyzing the byte structure.
  class ByteGuesser < Guesser
    # @return [Integer] the size in bytes of the ByteSet created.
    attr_reader :chunk_size

    # @param chunk_size [Integer] the size in bytes of the ByteSet to create.
    # @param (see Guesser#initialize)
    def initialize(chunk_size = nil, &block)
      @chunk_size = Integer(chunk_size) if chunk_size
      super(&block)
    end

    # {include:Guesser#available?}
    # @return [Boolean] does File respond to :getbyte?
    def available?
      File.instance_methods.include?(:getbyte)
    end

    # Invoke the test block on a ByteSet of `file`.
    # @param file (see Guesser#guess)
    # @return (see Guesser#guess)
    def guess(file)
      super(ByteSet.new(file, @chunk_size))
    end
  end
end
