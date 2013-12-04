# encoding: UTF-8
require_relative 'test_helper'
require 'shellrun'

class TestShellRunner < Minitest::Test
  def setup
    @runner = ShellRunner.new
  end

  def test_shell_output_and_exit_status
    str = 'Br farfoe<fc doidsiofdcC ;_' # do not assume UTF-8 support

    assert_nil   @runner.exitstatus
    assert_equal true,    @runner.ok?

    assert_equal Dir.pwd, @runner.run_command('pwd')
    assert_equal 0,       @runner.exitstatus
    assert_equal true,    @runner.ok?

    assert_equal str,     @runner.run_command('printf', '%s\n', str)
    assert_equal 0,       @runner.exitstatus
    assert_equal true,    @runner.ok?

    assert_equal '',      @runner.run_command('which', str)
    assert_equal 1,       @runner.exitstatus
    assert_equal false,   @runner.ok?

    assert_equal 'oops',  @runner.run_command('which', '-s', 'env', :'&&', 'echo', 'oops')
    assert_equal 0,       @runner.exitstatus
    assert_equal true,    @runner.ok?
  end
end
