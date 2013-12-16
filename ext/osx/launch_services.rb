# encoding: UTF-8
require 'shellwords'

module OSX
  # Lightweight wrapper around the `lsregister` core framework utility.
  module LaunchServices
    FRAMEWORK  = '/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework'
    LSREGISTER = File.join(FRAMEWORK, 'Versions/A/Support/lsregister')

    # force register app with LaunchServices
    def self.register(app, lint: false, verbose: false)
      options = ["-f #{File.expand_path(app).shellescape}"]
      options << '-lint' if lint
      lsregister("registering '#{app.pathmap('%f')}'", *options, verbose: verbose)
    end

    # unregister app with LaunchServices
    def self.unregister(app, lint: false, verbose: false)
      options = ["-u #{File.expand_path(app).shellescape}"]
      options << '-lint' if lint
      lsregister("unregistering '#{app.pathmap('%f')}'", *options, verbose: verbose)
    end

    # reseed LaunchServices database (non-destructive)
    def self.reseed(verbose: false)
      lsregister('reseeding the LaunchServices database', '-kill', '-seed', verbose: verbose)
    end

    # reset LaunchServices database (destroys user quarantine and URI handler permission cache)
    def self.reset!(local: true, system: true, user: true, verbose: false)
      domains = [].tap {|d|
        d << 'local'  if local
        d << 'system' if system
        d << 'user'   if user
      }
      lsregister('resetting the LaunchServices database', '-kill', "-r #{domains.join(',')}") unless domains.empty?
    end

    private
    def self.lsregister(action_desc, *options, verbose: false)
      options << '-v' if verbose == true
      out      = %x{#{LSREGISTER} #{options.join(' ')}}
      fail "Error #{action_desc}: `lsregister` returned #{$?.exitstatus}." unless $?.exitstatus == 0
      out.chomp
    end
  end
end
