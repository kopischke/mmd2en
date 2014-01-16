# encoding: UTF-8
require 'file_encoding/byte_set'
require 'file_encoding/guesser'
require 'forwardable'

module FileEncoding
  # Ordered queue of encoding guessers. aggregating confidence for encodings returned from each queue item.
  # @author Martin Kopischke
  # @version {FileEncoding::VERSION}
  class GuesserQueue
    extend Forwardable
    def_delegators :@guessers, :[], :<<, :push, :pop, :count, :length, :empty?, :each, :each_index

    # @param guessers [Array] the guessers to process, in order.
    # @option accept_dummy [true, false] return nil from processing if the guessed encoding is a dummy.
    # @option stop_threshold [Float] stop processing if aggregate confidence for an encoding is >= this value.
    # @option reject_threshold [Float] ignore encoding guesses whose confidence is < this value.
    def initialize(*guessers, accept_dummy: true, stop_threshold: 1.0, reject_threshold: 0.25)
      @guessers         = guessers
      @accept_dummy     = accept_dummy
      @stop_threshold   = stop_threshold
      @reject_threshold = reject_threshold
    end

    # Enqueued guessers available for encoding testing.
    # @return [Array] all guessers whose `available?` method returns true.
    def available_guessers
      @guessers.select {|e| e.available? }
    end

    # Process a file with the enqueued encoding guessers.
    # @param file [File, String] the file to process.
    # @return [Encoding] if an encoding could be guessed for `file` with the necessary certainty.
    # @return [nil] if no encoding could be guessed for `file` with the necessary certainty.
    def process(file)
      byte_set  = nil
      cache_set = cache_full_byte_set?
      guesses   = Hash.new(0.0)

      available_guessers.each do |g|
        guess_args = [file]

        # cache a full byte set when meeting the first ByteGuesser needing it
        # (generating full byte sets is expensive on large files, so we do this lazily)
        if cache_set && g.is_a?(ByteGuesser) && g.chunk_size.nil?
          byte_set ||= ByteSet.new(file)
          guess_args << byte_set
        end

        # guess encoding and skip if invalid
        guess = g.guess(*guess_args)
        next if guess.nil? || guess.encoding.dummy? && !@accept_dummy

        # store guess aggregate confidence
        guesses[guess.encoding] += guess.confidence
        return guess.encoding if guesses[guess.encoding] >= @stop_threshold
      end

      best_guess = guesses.max_by {|k,v| v }
      best_guess[0] unless best_guess.nil? || best_guess[1] < @reject_threshold
    end

    private
    def cache_full_byte_set?
      available_guessers.select {|e| e.is_a?(ByteSet) && e.chunk_size.nil? }.count > 1
    end
  end
end
