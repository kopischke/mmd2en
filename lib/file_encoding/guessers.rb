# encoding: UTF-8
require 'file_encoding/guessers/cheap'
require 'file_encoding/guessers/expensive'
require 'file_encoding/guessers/platform'

module FileEncoding
  # Guesser instance management library.
  # @author Martin Kopischke
  # @version {FileEncoding::VERSION}
  module Guessers
    # @return [Array] the default set of encoding guessers in recommended processing order.
    def self.default_set
      [].tap {|set|
        set << Cheap::CORE_BOM
        set << Cheap::MORE_BOM
        set << Platform::FILE
        set << Platform::APPLE_XATTR
        set << Expensive::ASCII
        set << Expensive::UTF
        set << Expensive::LATIN
      }
    end
  end
end
