# encoding: UTF-8
require 'date'
require 'forwardable'
require 'pathname'
require 'shellrun'
require 'tempfile'

# Quick an dirty module to sweeten AppleScript handling from Ruby via `osascript`.
# Allows creation of AppleScript data types (actually: a suitable string representation)
# from Ruby objects and straightforward script execution via `osascript`.
# @author Martin Kopischke
# @version {AppleScripter::VERSION}
module AppleScripter
  # The module version.
  VERSION = '1.0.0'

  # Included in classes mapping directly to their AppleScript counterparts.
  module Literal
    # @return [String] the representation of the object suitable for an AppleScript command.
    def to_applescript
      String(self)
    end
  end

  # @!method to_applescript
  #   Convert to the String representation of an AppleScript integer.
  #   @return (see AppleScripter::Literal#to_applescript)
  class ::Integer; include Literal; end

  # @!method to_applescript
  #   Convert to the String representation of an AppleScript real.
  #   @return (see AppleScripter::Literal#to_applescript)
  class ::Float; include Literal; end

  # @!method to_applescript
  #   Convert to the String representation of an AppleScript boolean.
  #   @return (see AppleScripter::Literal#to_applescript)
  class ::TrueClass; include Literal; end

  # @!method to_applescript
  #   Convert to the String representation of an AppleScript boolean.
  #   @return (see AppleScripter::Literal#to_applescript)
  class ::FalseClass; include Literal; end

  # @!method to_applescript
  #   Convert to the String representation of an AppleScript literal (use carefully).
  #   @return (see AppleScripter::Literal#to_applescript)
  class ::Symbol; include Literal; end

  class ::Object
    # Convert to String representation.
    # @return [String] the String representation of the Object.
    def to_applescript
      String(self).to_applescript
    end
  end

  class ::String
    # Convert to an escaped AppleScript String.
    # @return [String] the escaped AppleScript String (including quotes).
    def to_applescript
      '"' << self.gsub(/(?=["\\])/, '\\') << '"'
    end
  end

  module ::Enumerable
    # Convert to the String representation of an AppleScript list.
    # All elements are converted to their AppleScript representation.
    # @return [String] an AppleScript *list* representation.
    def to_applescript
      '{' << self.map(&:to_applescript).join(', ') << '}'
    end
  end

  class ::Hash
    # Convert to the String representation of an AppleScript record.
    # All keys are sanitized and all values re converted to their AppleScript representation.
    # @return [String] an AppleScript *record* representation.
    def to_applescript
      a = self.map do |k,v|
        k = String(k).gsub(/[^_[:alnum:]]/, '_')    # replace invalid key body chars by underscore
        k = '_' << k if k[0].match(/[^_[:alpha:]]/) # prefix keys starting with an invalid char
        "#{k}:#{v.to_applescript}"                  # because k << ':' << v will treat Integers as a codepoint
      end
      '{' << a.join(', ') << '}'
    end
  end

  class ::DateTime
    # Convert to the String representation of an AppleScript date.
    # @note AppleScript dates most closely match Ruby’s DateTime, not Date.
    # @return [String] an AppleScript *date* representation.
    def to_applescript # => "date \"<local format date>\""
      'date "' << OSARunner.new.run_script(*[
          "set theDate to current date",
          "set year of theDate to #{self.year}",
          "set month of theDate to #{self.month}",
          "set day of theDate to #{self.day}",
          "set hours of theDate to #{self.hour}",
          "set minutes of theDate to #{self.minute}",
          "set seconds of theDate to #{self.second}",
          "get theDate as text"
        ]) << '"'
    end
  end

  class ::Date
    # Convert to the String representation of an AppleScript date.
    # @note (see DateTime#to_applescript)
    # @return (see DateTime#to_applescript)
    def to_applescript
      self.to_datetime.to_applescript
    end
  end

  class ::Pathname
    # Convert to the String representation of an AppleScript file.
    # @note AppleScript’s *file* objects do not need to exist in the filesystem.
    # @return [String] an AppleScript *file* representation.
    def to_applescript
      'POSIX file ' << String(self.expand_path).to_applescript
    end
  end

  class ::File
    # Convert to the String representation of an ApplesScript alias.
    # @note AppleScript’s *alias* objects need to exist, like Ruby’s Files.
    # @return [String] an AppleScript *alias* representation.
    def to_applescript
      Pathname.new(self.path).to_applescript << ' as alias'
    end
  end

  # Run AppleScript scripts via `osascript` with convenience.
  class OSARunner
    extend Forwardable

    # @!attribute exitstatus [r]
    #   @return (see ShellRunner#exitstatus)
    # @!attribute ok? [r]
    #   @return (see ShellRunner#ok?)
    def_delegators :@sh, :exitstatus, :ok?

    def initialize
      @sh = ShellRunner.new
    end

    # Run a literal AppleScript.
    # @note Scripts are always run via Tempfile to avoid escaping conflicts between the shell,
    #   AppleScript and AppleScript strings.
    # @param lines [Array<#to_s>] the lines of the script to execute.
    # @return [String] the last output of the script.
    def run_script(*lines)
      Tempfile.open('AppleScripter') do |file|
        file.write(lines.join($/) << $/)
        file.close
        @sh.run_command('osascript', file.path)
      end
    end
  end
end
