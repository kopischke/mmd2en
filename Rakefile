# encoding: UTF-8
$:.push File.dirname(__FILE__)

require 'bundler/setup'
require 'CFPropertyList'
require 'rake/clean'
require 'rake/mustache_task'
require 'rake/testtask'
require 'rake/version_task'
require 'shellwords'
require 'version'

class Version
  def to_friendly
    names = {'a' => 'alpha', 'b' => 'beta', 'rc' => 'release candidate'}
    match = String(self).match(/^(.+)(#{names.keys.join('|')})([[:digit:]]+)?$/i)
    match ? "#{match[1]} #{names[match[2]]} #{match[3]}" : self
  end
end

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

BASE_NAME    = 'mmd2en'

BASE_DIR     = File.join(File.dirname(__FILE__))
BUILD_DIR    = File.join(BASE_DIR, 'build')
PACKAGE_DIR  = File.join(BASE_DIR, 'packages')

MAIN_SCRIPT  = "#{BASE_NAME}.rb"
APP_TEMPLATE = File.join(PACKAGE_DIR, 'service', "#{BASE_NAME}.platypus")

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

# rake automator
desc 'Generate Automator action.'
task :automator do
  base_dir   = File.join(PACKAGE_DIR, 'automator')
  project    = File.join(base_dir, "#{BASE_NAME}.xcodeproj")
  scheme     = BASE_NAME
  cmd_file   = File.join(base_dir, BASE_NAME, 'main.command')
  cmd_prefix = '#!/usr/bin/ruby -KuW0'

  # Generate main.command and make executable (Action will fail if the script is not!)
  %x{echo '#{cmd_prefix}' | cat - #{MAIN_SCRIPT.shellescape} >  #{cmd_file.shellescape} && chmod +x #{cmd_file.shellescape}}
  fail "Generation of '#{cmd_file}' failed with status #{$?.exitstatus}." unless $?.exitstatus == 0

  # XCode build
  build_settings = {
    'CONFIGURATION_BUILD_DIR' => BUILD_DIR.shellescape,
  }
  %x{cd #{base_dir.shellescape}; xcodebuild -scheme '#{scheme}' -configuration 'Release' #{build_settings.map {|k,v| "#{k}=#{v}" }.join(' ')}}

  # Post process Info.plist: set version numbers
  app_info = {
    'CFBundleVersion'            => version.to_s,       # Sync version numbers
    'CFBundleShortVersionString' => version.to_friendly # Sync version numbers
  }
  plist_merge!(File.join(BUILD_DIR, "#{scheme}.action", 'Contents', 'Info.plist'), app_info)
end

# rake mustache + file task for APP_TEMPLATE
Rake::MustacheTask.new(APP_TEMPLATE) do |task|
  task.verbose  = true
  task.template = "#{task.target}.mustache"
  task.data     = { base_dir: File.expand_path(BASE_DIR), base_name: BASE_NAME }
end

# rake service
desc 'Generate OS X Service provider application.'
task :service => APP_TEMPLATE do
  base_dir = File.join(PACKAGE_DIR, 'service')
  app_name = 'MultiMarkdown → Evernote'
  target   = File.join(BUILD_DIR, "#{app_name}.app")

  # Generate App bundle
  FileUtils.rm_r(target) if File.exist?(target) # Platypus’ overwrite flag `-y` is a noop as of 4.8
  %x{/usr/local/bin/platypus -l -I net.kopischke.#{BASE_NAME} -P #{APP_TEMPLATE.shellescape} #{target.shellescape}}
  fail "Generation of '#{target}' failed with status #{$?.exitstatus}." unless $?.exitstatus == 0

  # Post process Info.plist: set info not set by Platypus
  app_info = {
    'CFBundleVersion'            => version.to_s,                 # Sync version numbers
    'CFBundleShortVersionString' => version.to_friendly,          # Sync version numbers
    'LSBackgroundOnly'           => true,                         # Faceless background application
    'LSMinimumSystemVersion'     => '10.9.0'                      # Minimum for system Ruby 2
  }
  plist_merge!(File.join(target, 'Contents', 'Info.plist'), app_info)
end

desc 'Build all packages.'
task :build => [:clobber, :automator, :service]
