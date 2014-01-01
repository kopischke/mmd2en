# encoding: UTF-8
require 'core_ext/encoding'
require 'shellrun'

module CoreExtensions
  class ::File
    # Try to get the real encoding of a file (returns an Encoding, or nil).
    def self.real_encoding(path, accept_dummy: true)
      path = File.expand_path(path)
      sh   = ShellRunner.new

      file_guess = ->(fpath) {
        if sh.run_command('which', 'file').chomp.empty?
          warn 'File encoding guess skipped: `file` utility not found.'
          return nil
        else
          cset = sh.run_command('file', '-I', fpath).chomp.split('charset=').last
          fail "Error guessing file encoding: `file` returned #{sh.exitstatus}." unless sh.ok?
          Encoding.find_iana_charset(cset) unless cset.match(/binary/i)
        end
      }

      apple_text_encoding = ->(fpath) {
        if sh.run_command('which', 'xattr').chomp.empty?
          warn 'com.apple.TextEncoding test skipped: `xattr` utility not found.'
          return nil
        else
          cset = sh.run_command('xattr', '-p', 'com.apple.TextEncoding', fpath, :'2>/dev/null').chomp.split(';').first
          Encoding.find_iana_charset(cset) unless cset.nil?
        end
      }

      # note Apple’s TextEncoding lookup skews towards dummy UTF forms
      [file_guess, apple_text_encoding].each do |test|
        enc = test.call(path)
        return enc unless enc.nil? || enc.dummy? && !accept_dummy
      end
      nil
    end

    # Try to get the real external encoding of the File object.
    def real_encoding(**kwargs)
      File.real_encoding(self.path, **kwargs)
    end

    # Return the expanded form of the path used to create the File.
    def expanded_path
      File.expand_path(self.path)
    end
  end
end