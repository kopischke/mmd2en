# encoding: UTF-8
require 'file_encoding/guesser'

module FileEncoding
  module Guessers
    # Encoding guessers with high reliability and low operational overhead.
    # @author Martin Kopischke
    # @version {FileEncoding::VERSION}
    module Cheap
      # Reliable detector for UTF-(16|32)(BE|LE) on Ruby 1.9+.
      CORE_BOM = RubyGuesser.new({ruby: '>= 1.9'}) do |fn|
        File.open(fn, 'r:BOM|UTF-8:UTF-8') do |f|
          Guess.new(f.external_encoding, 1.0) if f.pos > 0 # we have skipped a BOM
        end
      end

      # Detector for some Byte Order Marks not detected by Ruby’s 'BOM|' open mode.
      # Adapted from the CMess gem, https://github.com/blackwinter/cmess.
      MORE_BOM = ByteGuesser.new(4) do |byte_set|
        enc = case
          when byte_set.starts_with?(0x2b, 0x2f, 0x76, [0x38, 0x39, 0x2b, 0x2f])
            Encoding::UTF_7
          when byte_set.starts_with?(0x84, 0x31, 0x95, 0x33)
            Encoding::GB18030
        end
        Guess.new(enc, 1.0) unless enc.nil?
      end
    end
  end
end
