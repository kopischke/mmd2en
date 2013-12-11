# encoding: UTF-8
$:.push File.join(File.dirname(__FILE__), 'ext')

require 'bundler/setup'
require 'info_plist'
require 'rake/clean'
require 'rake/mustache_task'
require 'rake/testtask'
require 'rake/version_task'
require 'shellwords'
require 'version'
require 'version/semantics'
require 'yaml'

def version
  Version.current
end

BASE_NAME     = 'mmd2en'
FULL_NAME     = 'MultiMarkdown → Evernote'

BASE_DIR      = File.join(File.expand_path(File.dirname(__FILE__)))
BUILD_DIR     = File.join(BASE_DIR, 'build')
PACKAGE_DIR   = File.join(BASE_DIR, 'packages')

MAIN_SCRIPT   = File.join(BASE_DIR, "#{BASE_NAME}.rb")
LIB_SCRIPTS   = FileList.new(File.join(BASE_DIR, 'lib', '*.rb'))
ALL_SCRIPTS   = LIB_SCRIPTS.dup.push(MAIN_SCRIPT)

APP_BUNDLE    = File.join(BUILD_DIR, "#{FULL_NAME}.app")
APP_TEMPLATE  = File.join(PACKAGE_DIR, 'service', "#{BASE_NAME}.platypus")
APP_SCRIPT    = File.join(PACKAGE_DIR, 'service', "#{BASE_NAME}.bash")
APP_YAML_DATA = FileList.new(File.join(PACKAGE_DIR, 'service', "#{BASE_NAME}.*.yaml"))

ACTION_BUNDLE = File.join(BUILD_DIR, "#{BASE_NAME}.action")
ACTION_XCODE  = File.join(BUILD_DIR, "#{BASE_NAME}.xcodeproj")

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

file ACTION_BUNDLE => [*ALL_SCRIPTS, ACTION_XCODE, BUILD_DIR] do |task|
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
  info_plist = InfoPList.new(ACTION_BUNDLE)
  info_plist.data.merge!(app_info)
  info_plist.write!
end

# file task for APP_TEMPLATE
Rake::MustacheTask.new do |task|
  task.target   = APP_TEMPLATE
  task.named    = {platypus: 'Generate Platypus template for OS X Service provider application'}
  task.verbose  = true
  task.template = "#{task.target}.mustache"
  task.data     = {
    base_dir:  File.expand_path(BASE_DIR),
    base_name: BASE_NAME
  }
end

# rake app
desc 'Generate OS X Service provider application.'
task :app => APP_BUNDLE

file APP_BUNDLE => [*ALL_SCRIPTS, APP_TEMPLATE, APP_SCRIPT, *APP_YAML_DATA, BUILD_DIR] do |task|
  lsregister = '/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister'

  if File.exist?(APP_BUNDLE) # Platypus’ overwrite flag `-y` is a noop as of 4.8
    puts 'Deleting previous app bundle...'
    %x{#{lsregister} -u #{APP_BUNDLE.shellescape}}
    FileUtils.rm_r(APP_BUNDLE)
  end

  %x{/usr/local/bin/platypus -l -I net.kopischke.#{BASE_NAME} -P #{APP_TEMPLATE.shellescape} #{APP_BUNDLE.shellescape}}
  fail "Generation of '#{APP_BUNDLE}' failed with status #{$?.exitstatus}." unless $?.exitstatus == 0

  # Post process Info.plist: set info not set by Platypus
  uti_defs = YAML.load_file(File.join(File.dirname(APP_TEMPLATE), "#{BASE_NAME}.utis.yaml"))
  supported_types = uti_defs.values
  supported_utis  = supported_types.map {|e| e['UTTypeIdentifier'] }

  doc_type       = { # declare MutiMarkdown compatible document handling
    'LSItemContentTypes'     => supported_utis,
    'CFBundleTypeRole'       => 'Viewer',
    'LSHandlerRank'          => 'None'
  }
  ns_services    = { # declare as Text service accepting compatible files
    'NSRequiredContext'      => {'NSServiceCategory' => 'public.text'},
    'NSSendFileTypes'        => supported_utis,
    'NSSendTypes'            => ['NSStringPboardType']
  }
  app_info       = { # Info.plist root
    'CFBundleDocumentTypes'      => [doc_type],          # override handled file types
    'UTImportedTypeDeclarations' => supported_types,     # import supported UTIs
    'CFBundleVersion'            => version.to_s,        # sync version numbers
    'CFBundleShortVersionString' => version.to_friendly, # sync version numbers
    'LSMinimumSystemVersion'     => '10.9.0'             # minimum for system Ruby 2
  }

  puts 'Rewriting Info.plist...'
  info_plist = InfoPList.new(APP_BUNDLE)
  info_plist.data.merge!(app_info)
  info_plist.data['NSServices'][0].merge!(ns_services)
  info_plist.write!

  puts 'Registering app with launch Services...'
  %x{#{lsregister} -f #{APP_BUNDLE.shellescape}}
end

# rake build
desc 'Build all packages.'
task :build => [:clobber, *PACKAGES]

# rake zip (because PackageTask’s logic is painful and its zip configuration sucks)
desc 'Zip all packages for upload to GitHub.'
task :zip => PACKAGES do |task|
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
