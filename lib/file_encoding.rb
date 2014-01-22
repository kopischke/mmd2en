# encoding: UTF-8
require 'file_encoding/byte_set'
require 'file_encoding/guesser'
require 'file_encoding/guessers'

# File encoding guessing library.
# @author Martin Kopischke
# @version {FileEncoding::VERSION}
module FileEncoding
  # Module version.
  VERSION = '1.0.0'

  # Extension to the core Ruby class to include Encoding guessing.
  class ::File
    # Guess a file’s text encoding.
    # @param file [File, String] the file whose encoding should be guessed.
    # @!macro [new] file_encoding.guess_args
    #   @param guessers [Array<Guesser>] the guessers to use, in order.
    #   @param with_dummies [Boolean] should dummy Encodings be included in the guesses?
    #   @param never_mind [Float] the confidence level < which guesses are discarded.
    # @return [Encoding] if an Encoding could be guessed with acceptable confidence.
    # @return [nil] if no Encoding could be guessed with acceptable confidence, or `file` is not a file.
    def self.guess_encoding(file, *guessers, with_dummies: true, never_mind: 0.1)
      return nil unless File.file?(File.realpath(file))
      guessers  = Guessers.default_set if guessers.empty?
      guesses   = Hash.new(0.0)
      guessers.lazy.map {|guesser|
          guess = guesser.guess(file)
          guess = nil if guess && guess.encoding.dummy? && !with_dummies
          guesses[guess.encoding] += guess.confidence unless guess.nil?
          guess
        }.take_while {|guess|
          guess.nil? || guesses[guess.encoding] < 1.0
        }.to_a
      best_guess, confidence = guesses.max_by {|k,v| v }
      best_guess unless confidence.to_f < never_mind
    end

    # Guess the file’s text encoding.
    # @!macro file_encoding.guess_args
    # @return (see self.guess_encoding)
    def guess_encoding(*guessers, **options)
      File.guess_encoding(self, *guessers, **options)
    end
  end
end
