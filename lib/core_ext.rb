require 'tempfile'

module ARGFParser
  # Returns an Array of all files passed, plus STDIN, as Files open for reading.
  # Does not block on empty STDIN and no files as it uses IO.dump.
  # Hat tip Onteria, http://rubyit.wordpress.com/2011/07/25/ruby-and-argf/
  def to_files
    files = []
    until ARGV.empty?   # files passed on command line
      files << File.new(ARGV[0]) rescue nil
      ARGV.shift
    end
    if self.path == '-' # STDIN
      file = self.file.dump
      files << File.new(file.path) unless file.nil?
    end
    files.compact
  end
end

ARGF.extend ARGFParser

class IO
  # Dump IO into a Tempfile (closed on return), without blocking.
  # Hat tip Eric Lubow, http://eric.lubow.org/2010/ruby/multiple-input-locations-from-bash-into-ruby/
  def dump
    return nil if self.closed?
    Tempfile.open('IO-dump') do |temp|
      temp.write(self.read_nonblock(1)) # raises IO::WaitReadable if IO is blocking
      self.each_line do |line| temp.write(line) end
      temp
    end
  rescue IO::WaitReadable, EOFError
    nil
  end

  # Like `dump`, but closes the IO stream after dumping.
  def dump!
    temp = self.dump and self.close
    temp
  end
end
