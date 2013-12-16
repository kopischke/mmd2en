# encoding: UTF-8
require 'shellwords'

module OSX
  # Lightweight wrapper around the `pbs` core service utility,
  # minus the unreliable documentation.
  module Services
    PBS = '/System/Library/CoreServices/pbs'

    # Print services information to stdout.
    def self.info(system: true, user: true, verbose: false)
      options = [].tap {|o|
        o << '-dump'       if system == true
        o << '-dump_cache' if user   == true
      }
      pbs('dumping Services information', *options, verbose: verbose)
    end

    # Force reload of all services information (note the man pages for `pbs` states
    # a far less expensive scan for new and modified services should happen on a `pbs`
    # call without options, but as of OSX 10.9, that just exits 1).
    def self.reload!(verbose: false)
      pbs('flushing Services information', '-flush', verbose: verbose)
    end

    # Preload service localizations (defaults to system locale).
    def self.preload_localizations(*languages, verbose: false)
      languages << %x{defaults read .GlobalPreferences AppleLocale}.split('_').first if languages.empty?
      pbs("preloading localizations for #{languages.join(', ')}", *languages, verbose: verbose)
    end

    private
    def self.pbs(description, *options, verbose: false)
      options << '-debug' if verbose == true
      out = %x{#{PBS} #{options.join(' ')}}
      fail "Error #{description}: `pbs` returned #{$?.exitstatus}." unless $?.exitstatus == 0
      out.chomp
    end
  end
end
