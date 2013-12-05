# encoding: UTF-8
require 'bundler/setup'
require 'rake/testtask'

BASE_NAME   = 'mmd2en'
MAIN_SCRIPT = "#{BASE_NAME}.rb"

# rake:test
Rake::TestTask.new do |task|
	task.libs.push 'lib'
	task.test_files = FileList['test/*_test.rb']
	task.verbose    = true
end

# rake:automator
desc 'Generate main.command script for Automator action.'
task :automator => MAIN_SCRIPT do
  base_dir    = 'packages/automator'
  project     = File.join(base_dir, "#{BASE_NAME}.xcodeproj")
  main_cmd    = File.join(base_dir, BASE_NAME, 'main.command')
  main_prefix = '#!/usr/bin/ruby -KuW0'
  %x{echo '#{main_prefix}' | cat - #{MAIN_SCRIPT} >  "#{main_cmd}"}
  %x{chmod +x "#{main_command}"}
  %x{open #{project}}
end

