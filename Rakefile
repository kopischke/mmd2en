# encoding: UTF-8
require 'bundler/setup'
require 'rake/clean'
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

def plist_merge!(plist_file, data)
  plist       = CFPropertyList::List.new(file: plist_file)
  plist_data  = CFPropertyList.native_types(plist.value)
  plist_data.merge!(data)
  plist.value = CFPropertyList.guess(plist_data)
  plist.save(plist_file, CFPropertyList::List::FORMAT_BINARY)
end

BASE_NAME   = 'mmd2en'
MAIN_SCRIPT = "#{BASE_NAME}.rb"
VERSION     = Version.current

RAKE_DIR    = File.join(File.dirname(__FILE__))
BUILD_DIR   = File.join(RAKE_DIR, 'build')
PACKAGE_DIR = File.join(RAKE_DIR, 'packages')

# rake:clobber
CLOBBER.include(File.join(BUILD_DIR, '*'))

# rake:test
Rake::TestTask.new do |task|
  task.libs.push 'lib'
  task.test_files = FileList['test/*_test.rb']
  task.verbose    = true
end

# rake:version[:...]
Rake::VersionTask.new do |task|
	task.with_git     = true
	task.with_git_tag = true
end

# rake:automator
desc 'Generate Automator action.'
task :automator do
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
    'CFBundleVersion'            => VERSION.to_s,       # Sync version numbers
    'CFBundleShortVersionString' => VERSION.to_friendly # Sync version numbers
  }
  plist_merge!(ENV['INFOPLIST_PATH'], app_info)
end

# rake:service
desc 'Generate OS X Service provider application.'
task :service do
  base_dir = File.join(PACKAGE_DIR, 'service')
  template = File.join(base_dir, "#{BASE_NAME}.platypus")
  app_name = 'MultiMarkdown → Evernote'
  target = File.join(BUILD_DIR, "#{app_name}.app")

  # Generate App bundle
  %x{/usr/local/bin/platypus -P #{"#{BASE_NAME}.platypus".shellescape} #{target.shellescape}}
  fail "Generation of '#{target}' failed with status #{$?.exitstatus}." unless $?.exitstatus == 0

  # Post process Info.plist: set info not set by Platypus
  app_info = {
    'CFBundleIdentifier'         => "net.kopischke.#{BASE_NAME}", # Platypus tends to overwrite this
    'CFBundleVersion'            => VERSION.to_s,                 # Sync version numbers
    'CFBundleShortVersionString' => VERSION.to_friendly,          # Sync version numbers
    'LSBackgroundOnly'           => true,                         # Faceless background application
    'LSMinimumSystemVersion'     => '10.9.0'                      # Minimum for system Ruby 2
  }
  plist_merge!(ENV['INFOPLIST_PATH'], app_info)
end

desc 'Build all packages.'
task :build => [:automator, :service]
