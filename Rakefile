# encoding: UTF-8
$:.push File.join(File.dirname(__FILE__), 'ext')

require 'bundler/setup'
require 'CFPropertyList'
require 'rake/clean'
require 'rake/mustache_task'
require 'rake/testtask'
require 'rake/version_task'
require 'shellwords'
require 'version'
require 'version/semantics'

def version
  Version.current
end

def plist_merge!(plist_file, data)
  plist       = CFPropertyList::List.new(file: plist_file)
  plist_data  = CFPropertyList.native_types(plist.value)
  plist_data.merge!(data)
  plist.value = CFPropertyList.guess(plist_data, convert_unknown_to_string: true)
  plist.save(plist_file, CFPropertyList::List::FORMAT_BINARY)
end

BASE_NAME     = 'mmd2en'
FULL_NAME     = 'MultiMarkdown → Evernote'

BASE_DIR      = File.join(File.expand_path(File.dirname(__FILE__)))
BUILD_DIR     = File.join(BASE_DIR, 'build')
PACKAGE_DIR   = File.join(BASE_DIR, 'packages')

MAIN_SCRIPT   = "#{BASE_NAME}.rb"
APP_TEMPLATE  = File.join(PACKAGE_DIR, 'service', "#{BASE_NAME}.platypus")
APP_BUNDLE    = File.join(BUILD_DIR, "#{FULL_NAME}.app")
ACTION_BUNDLE = File.join(BUILD_DIR, "#{BASE_NAME}.action")

PACKAGES      = [APP_BUNDLE, ACTION_BUNDLE]

# rake clean
CLEAN.include(APP_TEMPLATE)

# rake clobber
CLOBBER.include(File.join(BUILD_DIR, '*'))

# rake test
Rake::TestTask.new do |task|
  task.libs.push 'lib'
  task.test_files = FileList['test/*_test.rb']
  task.verbose    = true
end

# rake version[:...]
Rake::VersionTask.new do |task|
	task.with_git     = true
	task.with_git_tag = true
end

# directory BUILD_DIR
directory BUILD_DIR

# rake automator
desc 'Generate Automator action.'
task :automator => ACTION_BUNDLE

file ACTION_BUNDLE => BUILD_DIR do |task|
  base_dir   = File.join(PACKAGE_DIR, 'automator')
  project    = File.join(base_dir, "#{BASE_NAME}.xcodeproj")
  cmd_file   = File.join(base_dir, BASE_NAME, 'main.command')
  cmd_prefix = '#!/usr/bin/ruby -KuW0'

  # Generate main.command and make executable (Action will fail if the script is not!)
  %x{echo '#{cmd_prefix}' | cat - #{MAIN_SCRIPT.shellescape} >  #{cmd_file.shellescape} && chmod +x #{cmd_file.shellescape}}
  fail "Generation of '#{cmd_file}' failed with status #{$?.exitstatus}." unless $?.exitstatus == 0

  # XCode build
  build_settings = {
    'CONFIGURATION_BUILD_DIR' => BUILD_DIR.shellescape,
  }
  %x{cd #{base_dir.shellescape}; xcodebuild -scheme '#{BASE_NAME}' -configuration 'Release' #{build_settings.map {|k,v| "#{k}=#{v}" }.join(' ')}}

  # Post process Info.plist: set version numbers
  app_info = {
    'CFBundleVersion'            => version.to_s,       # Sync version numbers
    'CFBundleShortVersionString' => version.to_friendly # Sync version numbers
  }
  plist_merge!(File.join(ACTION_BUNDLE, 'Contents', 'Info.plist'), app_info)
end

# rake mustache + file task for APP_TEMPLATE
Rake::MustacheTask.new(APP_TEMPLATE) do |task|
  task.verbose  = true
  task.template = "#{task.target}.mustache"
  task.data     = { base_dir: File.expand_path(BASE_DIR), base_name: BASE_NAME }
end

# rake service
desc 'Generate OS X Service provider application.'
task :service => APP_BUNDLE

file APP_BUNDLE => [APP_TEMPLATE, BUILD_DIR] do |task|
  FileUtils.rm_r(APP_BUNDLE) if File.exist?(APP_BUNDLE) # Platypus’ overwrite flag `-y` is a noop as of 4.8
  %x{/usr/local/bin/platypus -l -I net.kopischke.#{BASE_NAME} -P #{APP_TEMPLATE.shellescape} #{APP_BUNDLE.shellescape}}
  fail "Generation of '#{APP_BUNDLE}' failed with status #{$?.exitstatus}." unless $?.exitstatus == 0

  # Post process Info.plist: set info not set by Platypus
  app_info = {
    'CFBundleVersion'            => version.to_s,                 # Sync version numbers
    'CFBundleShortVersionString' => version.to_friendly,          # Sync version numbers
    'LSBackgroundOnly'           => true,                         # Faceless background application
    'LSMinimumSystemVersion'     => '10.9.0'                      # Minimum for system Ruby 2
  }
  plist_merge!(File.join(APP_BUNDLE, 'Contents', 'Info.plist'), app_info)
end


desc 'Build all packages.'
task :build => [:clobber, *PACKAGES]

# rake package (because PackageTask’s logic is painful and its zip configuration sucks)
desc 'Zip all packages for upload to GitHub.'
task :package => PACKAGES do |task|
  zip_name    = "#{BASE_NAME}-packages-#{version}"
  excludes    = ['.DS_Store']
  zip_command = [
    'zip',
    '-m', # --move => delete zipped files
    '-r', # --recurse-paths
    "#{zip_name.shellescape}.zip",
    '.',  # from current dir
    '-x', # --exclude
    *excludes
  ]
  %x{cd #{BUILD_DIR.shellescape}; #{zip_command.join(' ')}}
  fail "Error generating package archive '#{zip_name}': `zip`returned #{$?.exitstatus}" unless $?.exitstatus == 0
end

desc 'Test and build.'
task :default => [:test, :build]
