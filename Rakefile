# encoding: UTF-8
require 'bundler/setup'
require 'rake/testtask'

# rake:test
Rake::TestTask.new do |task|
	task.libs.push 'lib'
	task.test_files = FileList['test/*_test.rb']
	task.verbose    = true
end
