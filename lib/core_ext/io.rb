# encoding: UTF-8
require 'tempfile'

module CoreExtensions
  # Extensions to the core IO class.
  # @see http://eric.lubow.org/2010/ruby/multiple-input-locations-from-bash-into-ruby/
  #   Eric Lubow on multiple Ruby input locations.
  # @author Martin Kopischke
  # @version {CoreExtensions::VERSION}
  class ::IO
    # Dump an IO stream into a Tempfile and open that in r+ mode.
    # @param options [Hash] options to pass to Tempfile.new.
    # @return [Tempfile] the temporary file with the dumped contents.
    def dump(**options)
      return nil if self.closed?
      temp = Tempfile.new('IO-dump', **options)
      self.each_line do |line| temp.write(line) end
      temp.close # finalize write
      temp.open  # re-open in r+ mode
      temp
    rescue => err
      temp.close! if temp
      raise err
    end

    # Like `dump`, but closes the IO stream after dumping.
    # @param (see #dump)
    # @return (see #dump)
    def dump!(**options)
      temp = self.dump(**options)
      self.close
      temp
    end

    # Test if a read from IO would block.
    # @return [true] if a read blocks (on pipes, STDIN and similar).
    # @return [false] if a read does not block.
    def read_blocking?
      b = self.read_nonblock(1) # raises IO::WaitReadable if IO is blocking
      self.ungetbyte(b)         # IO.rewind does not work on non-file streams
      false
    rescue IO::WaitReadable
      true
    rescue EOFError
      false
    end
  end
end
