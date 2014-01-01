# encoding: UTF-8
require 'core_ext/io'

module CoreExtensions
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

  ::ARGF.extend ARGFParser
end
