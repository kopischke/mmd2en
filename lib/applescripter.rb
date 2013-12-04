# encoding: UTF-8

# Quick an dirty module to sweeten AppleScript handling from Ruby via `osascript`.
# Allows creation of AppleScript data types (actually: a suitable string representation)
# from Ruby objects and straightforward script execution via `osascript`.
require 'date'
require 'forwardable'
require 'pathname'
require 'tempfile'

require_relative 'shellrun'

module AppleScripter
  module Literal
    def to_applescript
      String(self)
    end
  end

  # => Literal string representations
  class ::Integer;    include Literal; end # => AppleScript integer
  class ::Float;      include Literal; end # => AppleScript real
  class ::TrueClass;  include Literal; end # => AppleScript boolean
  class ::FalseClass; include Literal; end # => AppleScript boolean
  class ::Symbol;     include Literal; end # => AppleScript literal (careful with that one!)

  class ::Object # => default to escaped string representation
    def to_applescript
      String(self).to_applescript
    end
  end

  class ::String # => AppleScript escaped string
    def to_applescript
      '"' << self.gsub(/(?=["\\])/, '\\') << '"'
    end
  end

  module ::Enumerable # => AppleScript list, all elements converted
    def to_applescript
      '{' << self.map(&:to_applescript).join(', ') << '}'
    end
  end

  class ::Hash # => AppleScript record, all keys sanitized and values converted
    def to_applescript
      a = self.map do |k,v|
        k = String(k).gsub(/[^_[:alnum:]]/, '_')    # replace invalid key body chars by underscore
        k = '_' << k if k[0].match(/[^_[:alpha:]]/) # prefix keys starting with an invalid char
        "#{k}:#{v.to_applescript}"                  # because k << ':' << v will treat Integers as a codepoint
      end
      '{' << a.join(', ') << '}'
    end
  end

  class ::DateTime # => AppleScript date (which is a datetime anyway)
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

  class ::Date # => AppleScript date via cast to DateTime (see above)
    def to_applescript
      self.to_datetime.to_applescript
    end
  end

  class ::Pathname # => AppleScript file (as that need not exist in the filesystem)
    def to_applescript
      'POSIX file ' << String(self.expand_path).to_applescript
    end
  end

  class ::File # => ApplesScript alias (as that needs to exist, like Ruby’s File)
    def to_applescript
      Pathname.new(self.path).to_applescript << ' as alias'
    end
  end

  # Always run AppleScript commands via Tempfile to avoid escaping conflicts between the shell, AS and AS strings
  class OSARunner
    extend Forwardable
    def_delegators :@sh, :exitstatus, :ok?

    def initialize
      @sh = ShellRunner.new
    end

    def run_script(*lines)
      Tempfile.open('AppleScripter') do |file|
        file.write(lines.join($/) << $/)
        file.close
        @sh.run_command('osascript', file.path)
      end
    end
  end
end
