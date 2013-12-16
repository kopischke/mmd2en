# encoding: UTF-8
$:.push File.join(File.dirname(__FILE__), 'ext')

require 'bundler/setup'
require 'info_plist'
require 'rake/clean'
require 'rake/mustache_task'
require 'rake/testtask'
require 'rake/version_task'
require 'rake/zip_task'
require 'shellwords'
require 'version'
require 'version/conversions'
require 'yaml'

def version
  Version.current
end


# CONSTANTS
# ---------
BASE_NAME     = 'mmd2en'
FULL_NAME     = 'MultiMarkdown → Evernote'

# Build system directory structure
BASE_DIR      = File.join(File.expand_path(File.dirname(__FILE__)))
BUILD_DIR     = File.join(BASE_DIR, 'build')
PACKAGE_DIR   = File.join(BASE_DIR, 'packages')

# Core scripts
MAIN_SCRIPT   = File.join(BASE_DIR, "#{BASE_NAME}.rb")
LIB_SCRIPTS   = FileList.new(File.join(BASE_DIR, 'lib', '*.rb'))
ALL_SCRIPTS   = LIB_SCRIPTS.dup.push(MAIN_SCRIPT)

# Service provider app
APP_BUNDLE    = File.join(BUILD_DIR, "#{FULL_NAME}.app")
APP_BUNDLE_ID = "net.kopischke.#{BASE_NAME}"
APP_DIR       = File.join(PACKAGE_DIR, 'service')
APP_TEMPLATE  = File.join(APP_DIR, "#{BASE_NAME}.platypus")
APP_SCRIPT    = File.join(APP_DIR, "#{BASE_NAME}.bash")
APP_YAML_DATA = FileList.new(File.join(APP_DIR, "#{BASE_NAME}.*.yaml"))

# Automator action
ACTION_BUNDLE = File.join(BUILD_DIR, "#{BASE_NAME}.action")
ACTION_DIR    = File.join(PACKAGE_DIR, 'automator')
ACTION_XCODE  = File.join(ACTION_DIR, "#{BASE_NAME}.xcodeproj")

# Package upload contents
PACKAGES      = [APP_BUNDLE, ACTION_BUNDLE]


# TASKS
# -----
# rake clean
CLEAN.include(APP_TEMPLATE)

# rake clobber
CLOBBER.include(File.join(BUILD_DIR, '*'))

# rake test
Rake::TestTask.new do |t|
  t.libs.push 'lib'
  t.test_files = FileList['test/*_test.rb']
  t.verbose    = true
end

# rake version[:...]
Rake::VersionTask.new do |t|
	t.with_git     = true
	t.with_git_tag = true
end

# rake automator
Rake::SmartFileTask.new(ACTION_BUNDLE, [*ALL_SCRIPTS, ACTION_XCODE]) do |t|
  t.verbose = true
  t.action  = ->(*_) {
    # Generate main.command and make executable (Action will fail if the script is not x!)
    main_cmd      = File.expand_path(File.join(PACKAGE_DIR, 'automator', BASE_NAME, 'main.command'))
    main_cmd_path = main_cmd.shellescape
    %x{echo #!/usr/bin/ruby -KuW0 | cat - #{MAIN_SCRIPT.shellescape} > #{main_cmd_path} && chmod +x #{main_cmd_path}}
    fail "Generation of '#{main_cmd}' failed with status #{$?.exitstatus}." unless $?.exitstatus == 0

    # XCode build
    build_env   = {'CONFIGURATION_BUILD_DIR' => BUILD_DIR.shellescape}.map {|k,v| "#{k}=#{v}" }.join(' ')
    project_dir = ACTION_XCODE.pathmap('%d').shellescape
    %x{cd #{project_dir}; xcodebuild -scheme '#{BASE_NAME}' -configuration 'Release' #{build_env}}
  }
end

end

# rake platypus
Rake::MustacheTask.new(APP_TEMPLATE) do |t|
  t.named_task = {platypus: 'Generate Platypus template for OS X Service provider application'}
  t.verbose    = true
  t.data       = {
    base_dir:  File.expand_path(BASE_DIR),
    base_name: BASE_NAME,
    full_name: FULL_NAME,
    version:   version.to_s
  }
end

# rake app
Rake::SmartFileTask.new(APP_BUNDLE, [*ALL_SCRIPTS, APP_TEMPLATE, APP_SCRIPT, *APP_YAML_DATA, BUILD_DIR]) do |t|
  t.verbose = true
  t.action  = ->(*_){
    FileUtils.rm_r(APP_BUNDLE) if File.exist?(APP_BUNDLE) # Platypus’ overwrite flag `-y` is a noop as of 4.8
    puts "Generating app bundle from Platypus template '#{template.pathmap('%f')}'."
    %x{/usr/local/bin/platypus -l -I #{APP_BUNDLE_ID.shellescape} -P #{APP_TEMPLATE.shellescape} #{APP_BUNDLE.shellescape}}
    fail "Error generating '#{bundle.pathmap('%f')}': `platypus` returned #{$?.exitstatus}." unless $?.exitstatus == 0
  }
end


  supported_utis  = supported_types.map {|e| e['UTTypeIdentifier'] }

  }
    'CFBundleDocumentTypes'      => [doc_type],          # override handled file types
    'UTImportedTypeDeclarations' => supported_types,     # import supported UTIs
    'CFBundleShortVersionString' => version.to_friendly, # sync version numbers
    'LSMinimumSystemVersion'     => '10.9.0'             # minimum for system Ruby 2
  }

end

# rake build
desc 'Build all packages.'
task :build => [:clobber, *PACKAGES]

# rake zip
Rake::ZipTask.new(File.join(BUILD_DIR, "#{BASE_NAME}-packages-#{version}")) do |t|
  t.named_task = {zip: 'Zip all packages for upload to GitHub.'}
  t.files      = PACKAGES
  t.verbose    = true
end

desc 'Test and build.'
task :default => [:test, :build]
