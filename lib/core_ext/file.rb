# encoding: UTF-8
require 'file_encoding/queue'
require 'file_encoding/guessers'

module CoreExtensions
  # Extensions to the core File class.
  # @author Martin Kopischke
  # @version {CoreExtensions::VERSION}
  class ::File
    # Guess the text content encoding of a file.
    # @param file [File, String] the file whose encoding is to be guessed.
    # @param guessers [Array<FileEncoding::Guesser>] the encoding guessers to use
    #   (defaults to {FileEncoding::Guessers.default_set}).
    # @param guess_options [Hash] as in {FileEncoding::GuesserQueue#initialize}.
    # @return [Encoding] if an encoding could be guessed.
    # @return [nil] if no encoding could be guessed or `file` is not an existing file.
    def self.guess_encoding(file, *guessers, **guess_options)
      guessers = FileEncoding::Guessers.default_set if guessers.empty?
      queue    = FileEncoding::GuesserQueue.new(*guessers, **guess_options)
      queue.process(file) if File.file?(file)
    end

    # Guess the file’s text content encoding.
    # @param guessers [Array] as in {File.guess_encoding}.
    # @param guess_options [Hash] as in {File.guess_encoding}.
    # @return (see File.guess_encoding)
    def guess_encoding(*guessers, **guess_options)
      File.guess_encoding(self, *guessers, **guess_options)
    end

    # Get the expanded form of the path used to create the file.
    # @param dir_string [String] as in File.expand_path.
    # @return [String] the path.
    def expanded_path(dir_string = nil)
      File.expand_path(self, dir_string)
    end
  end
end
