# encoding: UTF-8
require 'file_encoding/guesser'
require 'yaml'

module FileEncoding
  module Guessers
    # Encoding guessers with a high operational overhead.
    # ByteGuessers adapted from the CMess gem, https://github.com/blackwinter/cmess.
    # @author Martin Kopischke
    # @version {FileEncoding::VERSION}
    module Expensive
      # Byte range ASCII detector: will also match 1 byte pane BOM-less UTF-8.
      ASCII = ByteGuesser.new do |byte_set|
        Guess.new(Encoding::ASCII, 1.0) if byte_set.count_of(0x00..0x7f) == byte_set.count
      end

      # Byte pattern UTF-(8|16|32) detector.
      UTF = ByteGuesser.new do |byte_set|
        enc = if byte_set.ratio_of(0x00) > 0.25
          # lots of NULL bytes indicate UTF-(16|32)
          case byte_set.first
          when 0x00 then Encoding::UTF_32
          when 0xfe then Encoding::UTF_16BE
          when 0xff then Encoding::UTF_16LE
          else           Encoding::UTF_16
          end
        else
          # number of escape-bytes matching following bytes indicates UTF-8
          esc_bytes = byte_set.count_of(0xc0..0xdf)     + # 110xxxxx 10xxxxxx
                      byte_set.count_of(0xe0..0xef) * 2 + # 1110xxxx 10xxxxxx 10xxxxxx
                      byte_set.count_of(0xf0..0xf7) * 3   # 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
          Encoding::UTF_8 if esc_bytes > 0 && esc_bytes == byte_set.count_of(0x80..0xbf)
        end
        Guess.new(enc, 0.75) unless enc.nil?
      end

      # Byte frequency 8-bit latin-1 and variants encoding detector
      # (somewhat of a misnomer, as it should detect non-latin ISO-8859 variants, albeit not well).
      LATIN = ByteGuesser.new do |byte_set|
        test_data = YAML.load_file(File.join(File.dirname(__FILE__), 'data', 'latin.yaml'))
        test_sets = Hash[test_data.map {|k,v| [Encoding.find(k), v] }]

        thresholds = (0.0004..0.1) # significant ratio to immediate accept ratio
        confidence =   (0.15..0.5) # confidence levels matching ratio levels

        ratios = []
        tested = test_sets.keys.take_while {|encoding|
          ratio   = byte_set.ratio_of(test_sets[encoding])
          ratios << ratio
          ratio   < thresholds.max
        }

        best_ratio = ratios.max
        unless best_ratio < thresholds.min
          # get first of best encoding matches with confidence scaled to ratio
          best_enc = tested[ratios.find_index(best_ratio)]
          Guess.new(best_enc, best_ratio.scale(thresholds, confidence).round(2))
        end
      end
    end
  end
end
