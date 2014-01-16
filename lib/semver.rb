# encoding: UTF-8

# Quick and dirty semantic versioning class: will recognize (and compare to)
# anything resembling a semantic version String after conversion (“resembling”
# because trailing 0s can be omitted, i.e. “4” will be considered as “4.0.0”).
# @note all parts are read-only and build information is dropped
#   – use a gem (like *Version* or *Versionify*) if you need greater capabilities.
# @see http://semver.org/ Semantic versioning specification.
# @author Martin Kopischke
# @version 1.0.0
class SemanticVersion
  include Comparable

  # Generate a SemanticVersion object from anything that can reasonably be cast to a version String.
  # @param version [String, Float, Integer, SemanticVersion] a version value.
  # @raise [ArgumentError] if `version` cannot be parsed into a semantic version.
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

  # Dynamic accessors for the version parts Hash.
  # @!attribute [r] major
  #  The major version number as defined by the Semantic Versioning spec.
  #  @return [Integer] the major version number.
  # @!attribute [r] minor
  #  The minor version number as defined by the Semantic Versioning spec.
  #  @return [Integer] the minor version number.
  # @!attribute [r] patch
  #  The patch number as defined by the Semantic Versioning spec.
  #  @return [Integer] the patch number.
  def method_missing(symbol)
    @version[symbol] || super
  end

  # All components of the semantic version number.
  # @return [Array<Integer>] in order of :major, :minor, :patch.
  def to_a
    @version.values
  end

  alias_method :to_ary, :to_a

  # All components of the semantic version number indexed by part name.
  # @return [Hash<Integer>] indexed on :major, :minor, :patch.
  def to_hash
    @version.dup
  end

  # The full semantic version number String matching the version.
  # @return [String] the canonical string representation.
  def to_s
    self.to_a.join('.')
  end

  alias_method :to_str, :to_s

  # Comparable base method.
  # @param (see #initialize)
  # @return [-1, 0, 1]
  def <=>(version)
    self.to_a <=> SemanticVersion.new(version).to_a
  end
end
