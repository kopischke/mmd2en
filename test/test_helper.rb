# encoding: UTF-8
gem 'minitest' # use gem, not builtin

require 'minitest/autorun'
require 'minitest/mock'
require 'minitest/stub_const'

begin # Minitest reporters are entirely optional
  require 'minitest/reporters'
  Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new
rescue LoadError
end

LIB_PATH ||= File.join(File.dirname(File.expand_path(__FILE__)), '..', 'lib')
$:.unshift(LIB_PATH)
