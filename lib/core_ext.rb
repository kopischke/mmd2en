require 'shellwords'
require 'tempfile'

module ARGFParser
  # Returns an Array of all files passed, plus STDIN, as Files open for reading.
  # Does not block on empty STDIN and no files as it uses IO.dump.
  # Hat tip Onteria, http://rubyit.wordpress.com/2011/07/25/ruby-and-argf/
  def to_files(**options)
    files = []
    until ARGV.empty?   # files passed on command line
      files << File.new(ARGV[0], 'r', **options) rescue nil
      ARGV.shift
    end
    if self.path == '-' # STDIN
      file = self.file.dump(**options)
      files << File.new(file.path) unless file.nil?
    end
    files.compact
  end
end

ARGF.extend ARGFParser

# Hat tip Eric Lubow, http://eric.lubow.org/2010/ruby/multiple-input-locations-from-bash-into-ruby/
class IO
  def dump(**options)
    return nil if self.closed?
    Tempfile.open('IO-dump', **options) do |temp|
      self.each_line do |line| temp.write(line) end
      temp
    end
  end

  # Like `dump`, but closes the IO stream after dumping.
  def dump!(**options)
    temp = self.dump(**options) and self.close
    temp
  end

  def read_blocking?
    b = self.read_nonblock(1) # raises IO::WaitReadable if IO is blocking
    self.ungetbyte(b)         # IO.rewind does not work on non-file streams
    false
  rescue IO::WaitReadable
    true
  rescue EOFError
    false
  end

  def real_encoding
    path = self.respond_to?(:path) ? self.dup.dump(binmode: true) : self.path
    path and File.real_encoding(path)
  end
end

class File
  def self.real_encoding(file)
    if %{which file}.chomp.empty?
      warn 'Unable to guess IO encoding: `file` utility not found.'
      return nil
    end

    path = file.respond_to?(:path) ? file.path : file
    enc = %x{file -I #{path.shellescape}}.chomp.split('charset=').last
    fail "Error guessing IO encoding: `file` returned #{$?.exitstatus}." unless $?.exitstatus == 0
    Encoding.find(enc) unless enc =~ /(unknown|binary)/
  end
end
