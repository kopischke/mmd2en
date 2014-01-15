# encoding: UTF-8
require 'core_ext/io'

module CoreExtensions
  # Extensions to the core ARGF object.
  # @see http://rubyit.wordpress.com/2011/07/25/ruby-and-argf/ Onteria on ARGF
  # @author Martin Kopischke
  # @version {CoreExtensions::VERSION}
  module ARGFParser
    # Returns an Array of files passed plus text content as files open for reading.
    # Does not hang when nothing is passed as it tests for blocking STDIN I/O.
    # @param options [Hash] options to pass to File.open and IO.dump.
    # @return [Array<File, Tempfile>] all files passed as Files, plus content on STDIN as Tempfile.
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
