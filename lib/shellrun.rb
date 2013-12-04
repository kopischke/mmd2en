# encoding: UTF-8
require 'shellwords'

# Lightweight %x{} wrapper to make it shell escaping safe and stubbable.
class ShellRunner
  attr_reader :exitstatus

  # Note every argument is a shell word and will be escaped as such, unless a symbol
  # i.e. run_command('echo', 'foo bar baz', :>, file.path) will run 'echo foo\ bar\ baz > <file.path>'.
  def run_command(*words)
    out = %x{#{words.map {|w| w.is_a?(Symbol) ? String(w) : String(w).shellescape }.join(' ')}}.chomp
    @exitstatus = $?.exitstatus
    out
  end

  def ok?
    @exitstatus == 0 || @exitstatus.nil?
  end
end
