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

class IO
  # Dump IO into a Tempfile (closed on return), without blocking.
  # Hat tip Eric Lubow, http://eric.lubow.org/2010/ruby/multiple-input-locations-from-bash-into-ruby/
  def dump(**options)
    return nil if self.closed?
    Tempfile.open('IO-dump', **options) do |temp|
      b = self.read_nonblock(1) # raises IO::WaitReadable if IO is blocking
      self.ungetbyte(b)         # IO.rewind does not work on STDIN
      self.each_line do |line| temp.write(line) end
      temp
    end
  rescue IO::WaitReadable, EOFError
    nil
  end

  # Like `dump`, but closes the IO stream after dumping.
  def dump!(**options)
    temp = self.dump(**options) and self.close
    temp
  end
end

class File
  def self.new(filename, mode = 'r', **opt)
    mode, opt = self.auto_encoding_mode(filename, mode, **opt)
    super(filename, mode, **opt)
  end

  def self.open(filename, mode = 'r', perm = nil, **opt, &block)
    mode, opt = self.auto_encoding_mode(filename, mode, **opt)
    super(filename, mode, **opt, &block)
  end

  # Simple `file` utility wrapper to guess encodings.
  def self.guess_encoding(filename)
    if %{which file}.chomp.empty?
      warn 'Unable to guess file encoding: `file` utility not found.'
      return nil
    end

    path = filename.is_a?(File) ? filename.path : String(filename)
    enc  = %x{file -I #{path.shellescape}}.chomp.split('charset=').last
    Encoding.find(enc) unless enc =~ /unknown/ || $?.exitstatus != 0
  end

  protected
  # Try to automagically set the external encoding files on guess_file_encoding: true.
  def self.auto_encoding_mode(filename, mode, **opt)
    path = filename.is_a?(File) ? filename.path : String(filename)
    if File.exist?(path) && opt[:guess_file_encoding] == true # ignore if not opening an existing file
      enc_mode     = mode.split(':')[1..-1] if mode.is_a?(String)
      enc_internal = Array(enc_mode)[1] || opt[:internal_encoding] || opt[:encoding] && opt[:encoding].split(':')[1]

      if enc_file = File.guess_encoding(path)                 # rewrite mode and opt by:
        mode = mode.split(':')[0] if enc_mode                 # – removing encoding information from mode
        opt.reject! {|k,v| k =~ /ternal_encoding/ }           # – removing (:internal|:external)_encoding options
        opt[:encoding] = [                                    # – setting the :encoding option
          String(enc_file).sub(/^UTF-(?=8|16)/i, 'BOM|UTF-'), #   (with BOM awareness for UTF-8 and UTF-16)
          String(enc_internal)
        ].compact.join(':')
      end
    end
    [mode, opt]
  end
end
