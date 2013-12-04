# encoding: UTF-8
require 'forwardable'

# Quick and dirty semantic versioning class – see http://semver.org/.
# Will recognize (and compare to) Strings and Numerics loosely matching the spec
# (“loosely” because trailing 0s can be dropped, i.e. “4” will be matched as “4.0.0”).
# Note build info is ignored and no version manipulation facilities are provided –
# use the Version gem if you need greater capabilities.
class SemanticVersion
  include Comparable

  extend Forwardable
  def_delegators :@version, :[], :keys, :values, :each

  def initialize(version)
    version  = String(version).strip
    match    = version.match(/^[0-9]+(?:\.[0-9]+){0,2}((?:[-+]).+)?$/) or
      raise ArgumentError, "'#{version}' is not a valid semantic version!"
    parts    = version.chomp(match[1]).split('.')
    @version = {
      major: Integer(parts[0]),
      minor: parts[1] ? Integer(parts[1]) : 0,
      patch: parts[2] ? Integer(parts[2]) : 0
    }
  end

  def to_str
    self.values.join('.')
  end

  alias_method :to_s, :to_str

  def <=>(version)
    self.values <=> SemanticVersion.new(version).values
  end
end
