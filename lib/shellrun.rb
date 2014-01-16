# encoding: UTF-8
require 'shellwords'

# Lightweight `%x{}` wrapper to make shell commands escaping safe and stubbable.
# @author Martin Kopischke
# @version 1.0.0
class ShellRunner
  # @return [Integer] exit status of the last run.
  attr_reader :exitstatus

  # Run a shell command.
  # @param words [Array<#to_s>] the shell words making up the command.
  # @return [String] stdout output from the command (chomped).
  # @note Every argument is a shell word and will be escaped as such, unless a symbol.
  # @example `run_command('echo', 'foo bar baz', :>, file.path)` will run 'echo foo\ bar\ baz > <file.path>'.
  def run_command(*words)
    out = %x{#{words.map {|w| w.is_a?(Symbol) ? String(w) : String(w).shellescape }.join(' ')}}.chomp
    @exitstatus = $?.exitstatus
    out
  end

  # Test if last exit status was 0.
  # @return [true] if the last exit status was 0, or no command has been run yet.
  # @return [false] if the last command’s exit status wasn‘t 0.
  def ok?
    @exitstatus == 0 || @exitstatus.nil?
  end
end
