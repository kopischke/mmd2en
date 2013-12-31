require 'shellwords'
require 'tempfile'

module ARGFParser
  # Returns an Array of all files passed, plus text content, as Files open for reading.
  # Does not hang when nothing is passed as it tests for blocking STDIN I/O.
  # Hat tip Onteria, http://rubyit.wordpress.com/2011/07/25/ruby-and-argf/
  def to_files(**options)
    files = []
    until ARGV.empty?   # files passed on command line
      files << File.new(ARGV[0], 'r', **options) rescue nil
      ARGV.shift
    end
    if self.path == '-' # STDIN
      file = self.file.dump(**options) unless self.file.read_blocking?
      file and files << file
    end
    files.compact
  end
end

ARGF.extend ARGFParser

# Hat tip Eric Lubow, http://eric.lubow.org/2010/ruby/multiple-input-locations-from-bash-into-ruby/
class IO
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

class File
  # Try to get the real encoding of a file (returns an Encoding, or nil).
  def self.real_encoding(path)
    path = File.expand_path(path)

    file_guess = ->(fpath) {
      if %{which file}.chomp.empty?
        warn 'File encoding guess skipped: `file` utility not found.'
        return nil
      else
        cset = %x{file -I #{fpath.shellescape}}.chomp.split('charset=').last
        fail "Error guessing file encoding: `file` returned #{$?.exitstatus}." unless $?.exitstatus == 0
        Encoding.find_iana_charset(cset) unless cset.match(/binary/i)
      end
    }

    apple_text_encoding = ->(fpath) {
      if %{which xattr}.chomp.empty?
        warn 'com.apple.TextEncoding test skipped: `xattr` utility not found.'
        return nil
      else
        cset = %x{xattr -p com.apple.TextEncoding #{fpath.shellescape} 2>/dev/null}.chomp.split(';').first
        Encoding.find_iana_charset(cset) unless cset.nil?
      end
    }

    # note Apple’s TextEncoding lookup skews towards dummy UTF forms
    [file_guess, apple_text_encoding].each do |test|
      enc = test.call(path)
      return enc unless enc.nil? || enc.dummy?
    end
    nil
  end

  def real_encoding
    File.real_encoding(self.path)
  end
end

class Encoding
  # Find IANA mappings `Encoding.find` will miss.
  # http://www.iana.org/assignments/character-sets/character-sets.xhtml
  def self.find_iana_charset(name)
    iana_mappings = {
      'macintosh'    => 'macRoman',
      'unknown-8bit' => nil
    }
    ruby_encoding = iana_mappings.fetch(String(name).downcase, name)
    ruby_encoding and self.find(ruby_encoding)
  end
end
