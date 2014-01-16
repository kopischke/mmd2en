# encoding: UTF-8
require 'core_ext/encoding'
require 'file_encoding/guesser'
require 'rbconfig'

module FileEncoding
  module Guessers
    # Platform specific encoding guessers.
    # @author Martin Kopischke
    # @version {FileEncoding::VERSION}
    module Platform
      # `file -I` reliably detects ASCII and UTF flavors, defaults to binary or unknown-8bit.
      FILE = ShellGuesser.new('file', '-I') do |out|
        cset = out.split('charset=').last
        enc  = Encoding.find_iana_charset(cset) unless cset.match(/binary/i)
        Guess.new(enc, 1.0) if enc
      end

      # `com.apple.TextEncoding` xattr considered reliable on OS X, less o on other platforms
      # (which may or may not have transcoded while preserving the xattr value).
      APPLE_XATTR = ShellGuesser.new('xattr', '-p', 'com.apple.TextEncoding') do |out|
        cset = out.split(';').first
        enc  = Encoding.find_iana_charset(cset) unless cset.nil?
        if enc
          confidence = RbConfig::CONFIG['host_os'].match(/darwin|mac os/i) ? 0.75 : 0.25
          Guess.new(enc, confidence)
        end
      end
    end
  end
end
