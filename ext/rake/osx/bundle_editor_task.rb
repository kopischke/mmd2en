# encoding: UTF-8
require 'osx/launch_services'
require 'osx/plist'
require 'osx/services'
require 'rake/tasklib'

module Rake
  module OSX
    # Rake task to post-process OS X application bundles.
    class BundleEditorTask < TaskLib
      attr_accessor :name, :description, :bundle
      attr_accessor :add_resources, :add_localizations, :edit_info, :set_version, :set_build, :verbose
      attr_writer   :register_services

      # binds `puts` to Rake default output, quiet unless @verbose is set
      include Rake::ReducedOutput

      def initialize(name, bundle = nil, description: '',
                     resources: [], localizations: {}, info: nil,
                     version: nil, build: version,
                     services: nil, verbose: false)
        @name              = String(name).strip.downcase.to_sym
        @description       = String(description)
        @bundle            = bundle
        @add_resources     = resources
        @add_localizations = localizations
        @edit_info         = info
        @register_services = services
        @set_version       = version
        @set_build         = build
        @verbose           = verbose
        yield(self) if block_given?
        define unless @name.nil? || @bundle.nil?
      end

      # the full service rescan is expensive, so we defer to a user setting (nil = auto)
      def register_services
        @register_services.nil? and @register_services = ::OSX::PList.open(@bundle).keys.include?('NSServices')
      end

      private
      def define
        resource_dir  = File.join(@bundle, 'Contents', 'Resources')
        language_dirs = @add_localizations.map {|k,_| File.join(resource_dir, "#{String(k)}.lproj") }

        # create '.lproj' directories where needed
        language_dirs.each do |dir| directory dir end

        # create main task
        desc @description if @description
        task @name => [@bundle, *language_dirs] do
          ::OSX::LaunchServices.unregister(@bundle, verbose: @verbose)

          # add resources
          puts "Adding resources to '#{@bundle.pathmap('%f')}'..." unless @add_resources.empty?
          @add_resources.each do |res| cp_r(res, resource_dir) end

          # add localization files
          unless @add_localizations.empty?
            puts "Adding localizations to '#{@bundle.pathmap('%f')}'..."
            @add_localizations.each do |lang, glob| cp_r(glob, File.join(resource_dir, "#{String(lang)}.lproj")) end
            localizations = Dir.glob(File.join(resource_dir, '*.lproj')).map {|e| e.pathmap('%n') }
          end

          # modify Info.plist
          unless localizations.nil? && @edit_info.nil? && @set_version.nil? && @set_build.nil?
            ::OSX::PList.open(@bundle) do |data|
              puts "Setting Info.plist values for '#{@bundle.pathmap('%f')}'..."
              data = data.merge({'CFBundleLocalizations' => localizations}) unless localizations.nil?
              data = @edit_info.respond_to?(:call) ? @edit_info.call(data) : data.merge(@edit_info) unless @edit_info.nil?
              data = data.merge({'CFBundleShortVersionString' => @set_version}) unless @set_version.nil?
              data = data.merge({'CFBundleVersion' => @set_build}) unless @set_build.nil?
              data
            end
          end

          # register modified bundle with the system
          ::OSX::LaunchServices.register(@bundle, lint: true, verbose: @verbose)
          ::OSX::Services.reload!(verbose: @verbose) if register_services
        end
      end
    end
  end
end
