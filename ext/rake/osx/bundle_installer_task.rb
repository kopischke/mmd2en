# encoding: UTF-8
require 'rake/smart_file_task'

module Rake
  module OSX
    # Rake task to install OS X application bundles.
    class BundleInstallerTask < SmartFileTask
      attr_accessor :user_install, :move_bundle
      attr_reader   :bundle_type

      # syntactic sugar
      alias :bundle  :base
      alias :bundle= :base=

      # restrict `actions` and `args` access to r/o
      protected :action=, :args=

      def initialize(to_install, type = nil, user_install: nil, move_bundle: true, **kwargs, &block)
        @bundle_type  = type || guess_type(to_install)
        @user_install = user_install
        @move_bundle  = move_bundle
        action = ->(*_) { @move ? mv(@base, @target) : cp_r(@base, @target) unless @base == @target }
        super(install_to(to_install), to_install, action, **kwargs, &block)
      end

      def bundle_type=(type)
        @bundle_type = type
        @target      = install_to(@base)
      end

      private
      def guess_type(to_install)
        type = to_install.pathmap('%x').downcase.to_sym
      end

      def install_to(to_install)
        location = {
          app:        ['application folder', 'local domain', nil],
          action:     ['library folder', 'user domain', ['Automator']],
          mailbundle: ['library folder', 'user domain', ['Mail', 'Bundles']],
          prefpane:   ['system preferences', 'user domain'],
          quicklook:  ['library folder', 'user domain', ['QuickLook']],
          service:    ['services folder', 'user domain', nil],
          workflow:   ['workflows folder', 'user domain', nil]
        }
        err_unknown = ->{ fail "Unable to install bundle of unknown type 'type'." }

        descriptor = "path to #{location.fetch(@bundle_type, err_unknown)[0]} from #{location[@bundle_type][1]}"
        install_to = %x{osascript -e 'get POSIX path of (#{descriptor})'}
        $?.exitstatus == 0 or fail "Unable to retrieve installation path: `osascript` returned #{$?.exitstatus}."
        location[@bundle_type][2].tap {|e| e and install_to = File.join(install_to, *e) }
        File.join(install_to, to_install.pathmap('%f'))
      end
    end
  end
end
