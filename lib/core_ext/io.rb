# encoding: UTF-8
require 'tempfile'

module CoreExtensions
  # Hat tip Eric Lubow, http://eric.lubow.org/2010/ruby/multiple-input-locations-from-bash-into-ruby/
  class ::IO
    # Dump IO into a Tempfile open in r+ mode.
    def dump(**options)
      return nil if self.closed?
      temp = Tempfile.new('IO-dump', **options)
      self.each_line do |line| temp.write(line) end
      temp.close # finalize write
      temp.open  # re-open in r+ mode
      temp
    rescue => e
      temp.close! if temp
      raise e
    end

    # Like `dump`, but closes the IO stream after dumping.
    def dump!(**options)
      temp = self.dump(**options)
      self.close
      temp
    end

    # Test if a read from IO would block (true on pipes etc.)
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
