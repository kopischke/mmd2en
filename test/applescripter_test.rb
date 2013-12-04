# encoding: UTF-8
require_relative 'test_helper'
require 'applescripter'

class TestAppleScripterInclude < Minitest::Test
  include AppleScripter

  def setup
    @generic = /^.+$/
  end

  # Object.to_applescript: defaults to String
  def test_objects_convert_correctly
    assert_respond_to @generic, :to_applescript
    assert_equal String(@generic).to_applescript, @generic.to_applescript
  end

  # String.to_applescript: escapes
  def test_strings_convert_correctly
    str = 'Foo "bar \baz"'
    assert_respond_to str, :to_applescript
    assert_equal "\"Foo \\\"bar \\\\baz\\\"\"", str.to_applescript
  end

  # Integer, Float, Symbol, True and False.to_applescript: literals
  def test_literals_convert_correctly
    [rand(1000), rand(1000)+rand, true, false, :stuff].each do |literal|
      assert_respond_to literal, :to_applescript
      assert_equal String(literal), literal.to_applescript
    end
  end

  # Array, Set and Hash.to_applescript: list resp. collection (for Hash)
  def test_collections_convert_correctly
    ary  = ['Foo', 1, 2.5, @generic]
    list = "{\"Foo\", 1, 2.5, \"#{String(@generic)}\"}"
    assert_respond_to ary, :to_applescript
    assert_equal list, ary.to_applescript

    require 'set'
    set = Set.new(ary)
    assert_respond_to set, :to_applescript
    assert_equal list, set.to_applescript

    hash = {'a string/thing' => "foo bar", :b => 123, 45 => @generic}
    assert_respond_to hash, :to_applescript
    assert_equal "{a_string_thing:\"foo bar\", b:123, _45:\"#{String(@generic)}\"}", hash.to_applescript
  end

  # Date and DateTime.to_applescript: date string
  def test_date_time_convert_correctly
    [Date.today, DateTime.now].each do |date|
      assert_respond_to date, :to_applescript
      refute_nil (date_as = date.to_applescript.match(/^date \"(.+)\"$/))
      {
        year:   Integer(%x{osascript -e 'get year of #{date_as} as integer'}.chomp),
        month:  Integer(%x{osascript -e 'get month of #{date_as} as integer'}.chomp),
        day:    Integer(%x{osascript -e 'get day of #{date_as} as integer'}.chomp),
        hour:   Integer(%x{osascript -e 'get hours of #{date_as} as integer'}.chomp),
        minute: Integer(%x{osascript -e 'get minutes of #{date_as} as integer'}.chomp),
        second: Integer(%x{osascript -e 'get seconds of #{date_as} as integer'}.chomp)
      }.each do |part, value| # ignore GMT offset as that is lost in translation
        assert_equal date.send(part), value if date.respond_to?(part)
      end
    end
  end

  # Pathname and File.to_applescript
  def test_filesystem_objects_convert_correctly
    path = File.expand_path(__FILE__)

    path = Pathname.new(path)
    assert_respond_to path, :to_applescript
    assert_equal "POSIX file \"#{path}\"", path.to_applescript

    File.open(path) do |file|
      file.close
      assert_respond_to file, :to_applescript
      assert_equal "POSIX file \"#{path}\" as alias", file.to_applescript
    end
  end
end

class TestOSARunner < Minitest::Test
  def setup
    @runner = AppleScripter::OSARunner.new
  end

  def test_osa_runner_exposes_shellrunner_methods
    [:exitstatus, :ok?].each do |m| assert_respond_to @runner, m end
  end

  def test_osa_runner_executes_applescript_command
    command  = ['tell application "System Events"', 'get desktop folder of user domain', 'end tell']
    response = %x{osascript #{command.map {|e| %Q{-e '#{e}'}}.join(' ')}}.chomp
    exited   = $?.exitstatus
    assert_equal response, @runner.run_script(*command)
    assert_equal exited,   @runner.exitstatus
  end
end
