# encoding: UTF-8
require 'osx/plist'

module OSX
  class Bundle
    attr_reader  :path, :info_plist, :resources_dir
    alias_method :to_str, :path

    def initialize(bundle_path)
      fail "Bundle '#{bundle_path}' is not a valid bundle." unless File.directory?(bundle_path)
      @path          = File.expand_path(bundle_path)
      @info_plist    = File.join(@path, 'Contents', 'Info.plist')
      @resources_dir = File.join(@path, 'Contents', 'Resources')
    end

    def type
      # check this dynamically as it can be changed outside the object.
      type = @path.split('.').last.downcase.to_sym
      case type
      when :workflow
        service_info = PList.open(@info_plist)['NSServices']
        service_info && !service_info.empty? ? :service : :workflow
      else
        type
      end
    end

    def name
      info = PList.open(@info_plist)
      info['CFBundleDisplayName'] || info['CFBundleName']
    end

    def version
      info    = PList.open(@info_plist)
      version = info['CFBundleShortVersionString']
      build   = info['CFBundleVersion']
      version ? "#{version}#{build != version and " (#{build})"}" : build
    end

    def info(&block)
      PList.open(@info_plist, &block)
    end

    def resources
      Dir.glob(File.join(@resources_dir, '**'))
    end

    def localizations
      localization_dirs = Dir.glob(File.join(@resources_dir, '*.lproj'))
      localizations     = localization_dirs.map {|dir|
        locale = File.basename(dir, '.lproj')
        [locale, dir] unless locale == 'Base'
      }.flatten.compact
      Hash[*localizations]
    end

    def install!(to_folder = nil, user_install: nil, move_bundle: true, overwrite_existing: true)
      if to_folder.nil?
        location   = {
          app:        ['application folder', 'local domain', nil],
          action:     ['library folder', 'user domain', ['Automator']],
          mailbundle: ['library folder', 'user domain', ['Mail', 'Bundles']],
          prefpane:   ['system preferences', 'user domain'],
          quicklook:  ['library folder', 'user domain', ['QuickLook']],
          service:    ['services folder', 'user domain', nil],
          workflow:   ['workflows folder', 'user domain', nil]
        }[type] or fail "Unable to install bundle of unknown type '#{type}'."

        domain     = user_install.nil? ? location[1] : (user_install ? 'user domain' : 'local domain')
        descriptor = "path to #{location[0]} from #{domain}"

        to_folder  = %x{osascript -e 'get POSIX path of (#{descriptor})'}.chomp
        fail "Unable to retrieve installation path: `osascript` returned #{$?.exitstatus}." unless $?.exitstatus == 0
        to_folder  = File.join(target_root, *location[2])
      end

      osa_cmd = [
        %Q{tell application "Finder"},
        %Q{set theFolder to folder (POSIX file "#{to_folder}")},
        %Q{set theBundle to (POSIX file "#{@path}")},
        %Q{#{move_bundle ? 'move' : 'duplicate' } theBundle to folder theFolder#{' with replacing' if overwrite_existing}},
        %Q{end tell}
      ]
      %x{osascript -e '#{osa_cmd.join("' -e '")}'}
      $?.exitstatus == 0 or fail "Unable to install #{File.basename(@path)}: `osascript` returned #{$?.exitstatus}."
    end

  end
end
