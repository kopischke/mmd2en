# encoding: UTF-8

# Quick and dirty semantic versioning class – see http://semver.org/.
# Will recognize (and compare to) Strings and Numerics loosely matching the spec
# (“loosely” because trailing 0s can be dropped, i.e. “4” will be matched as “4.0.0”).
# Note build info is ignored and no version manipulation facilities are provided –
# use the Version gem if you need greater capabilities.
class SemanticVersion
  include Comparable

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

  def method_missing(symbol)
    @version[symbol] || super
  end
  # All components of the semantic version number.
  def to_a
    @version.values
  end

  alias_method :to_ary, :to_a

  # All components of the semantic version number indexed by part name.
  def to_hash
    @version.dup
  end

  # The full semantic version number String matching the version.
  def to_s
    self.to_a.join('.')
  end

  alias_method :to_str, :to_s

  def <=>(version)
    self.to_a <=> SemanticVersion.new(version).to_a
  end
end
