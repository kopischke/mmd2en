# encoding: UTF-8

# Semantic Versioning conforming version class.
#
# A SemanticVersion object will validate (and compare to) anything resembling
# a semantic version String after conversion (“resembling” because trailing 0s
# can be omitted, i.e. “4” will be equivalent to “4.0.0”).
#
# @example Creating and comparing semantic versions:
#   SemanticVersion.new('1.1.2') < 1.2                   # => true
#   SemanticVersion.new(1.2) == '1.2.0'                  # => true
#   SemanticVersion.new('2.0+b.212') == '2.0.0'          # => true
#   SemanticVersion.new('2.0-pre.1') < 2                 # => true
#   SemanticVersion.new(1) > SemanticVersion.new('2.19') # => false
#
# SemanticVersion versions can be bumped in a spec conforming fashion.
#
# @example Bumping versions:
#   SemanticVersion.new('1.1.2').bump.to_full_version         # => "1.1.3"
#   SemanticVersion.new('1.1.2').bump(:minor).to_full_version # => "1.2.0"
#   SemanticVersion.new('1.1.2').bump(:major).to_full_version # => "2.0.0"
#   with_pre_info = SemanticVersion.new('1.0-pre')
#   with_pre_info.to_full_version                             # => "1.0.0-pre"
#   with_pre_info.bump(:minor).to_full_version                # => "1.1.0"
#
# @see http://semver.org/ Semantic Versioning specification.
# @note build and prerelease metadata is retained, but not used in comparisons.
#
# @author Martin Kopischke
# @version {SemanticVersion::VERSION}
class SemanticVersion
  include Comparable

  # The class version.
  VERSION          = '1.1.0'
  # The supported Semantic Version specification version.
  SPEC_VERSION     = '2.0.0'
  # The canonical part names of a semantic version.
  VERSION_PARTS    = [:major, :minor, :patch]
  # Matches spec conforming metadata tails.
  METADATA_PATTERN = '([-+])([A-Za-z0-9][-A-Za-z0-9]*(?:\.[A-Za-z0-9][-A-Za-z0-9]*)*)$'
  # Matches spec conforming version strings.
  VERSION_PATTERN  = "^([0-9]+(?:\.[0-9]+){0,2})(?:#{METADATA_PATTERN})?$"

  private_constant :METADATA_PATTERN, :VERSION_PATTERN

  # @return [String] the trailing version info part, if any.
  attr_reader :metadata

  # Create a new SemanticVersion object from version input.
  # @param version [#to_s] a valid version value after String conversion.
  # @raise [ArgumentError] if `version` cannot be parsed as a semantic version.
  def initialize(version)
    version  = String(version).strip
    match    = version.match(Regexp.new(VERSION_PATTERN)) or
      fail ArgumentError, "'#{version}' is not a valid semantic version!"
    parts    = match[1].split('.')
    @version = {
      VERSION_PARTS[0] => Integer(parts[0]),
      VERSION_PARTS[1] => parts[1] ? Integer(parts[1]) : 0,
      VERSION_PARTS[2] => parts[2] ? Integer(parts[2]) : 0
    }
    @metadata   = String(match[3])
    @prerelease = match[2] == '-'
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

  # Get a new SemanticVersion object with a version bump.
  # @note bumping sets all version parts below the bumped one to 0
  #   and voids all metadata (use {#metadata=} to set metadata info).
  # @param part [Symbol] the version part to bump.
  # @return [SemanticVersion] a new SemanticVersion.
  def bump(part = VERSION_PARTS.last)
    self.to_version.bump!(part)
  end

  # Bump the version.
  # @param (see #bump)
  # @return [self]
  def bump!(part = VERSION_PARTS.last)
    fail ArgumentError, "'#{part}' is not a valid version part!" unless VERSION_PARTS.include?(part)
    @version[part] += 1
    VERSION_PARTS.reverse.take_while {|p| p != part }.each do |p| @version[p] = 0 end
    self.metadata = ''
    self
  end

  # Kill prerelease info.
  # @return [self]
  def release!
    self.metadata = '' if prerelease?
    self
  end

  # (Re-)set version metadata.
  # @param metadata [String] the metadata info, including the leading '+' or '-'.
  # @return [void]
  # @raise [ArgumentError] if `metadata`is not valid metadata String.
  def metadata=(metadata)
    match = metadata.match(Regexp.new(METADATA_PATTERN))
    if match
      @metadata   = String(match[2])
      @prerelease = match[1] == '-'
    elsif !metadata.empty?
      fail ArgumentError, "'#{metadata}' is not valid metadata!"
    else
      @metadata   = ''
      @prerelease = false
    end
  end

  # Check if this a pre-release version.
  # @return [Boolean] is this a pre-release?
  def prerelease?
    @prerelease == true
  end

  # All parts the version.
  # @return [Array<Integer>] in order of {VERSION_PARTS}.
  def to_a
    VERSION_PARTS.map {|part| @version[part] }
  end

  alias_method :to_ary, :to_a

  # All parts of the version, indexed by {VERSION_PARTS} values.
  # @return [Hash<Symbol, Integer>].
  def to_h
    @version.dup
  end

  alias_method :to_hash, :to_h

  # @return [String] the version String representation, **excluding** metadata.
  def to_s
    self.to_a.join('.')
  end

  alias_method :to_gem_version, :to_s

  # @return [String] the version String representation, **including** metadata.
  def to_str
    "#{self.to_s}#{prerelease? ? '-' : '+' unless @metadata.empty?}#{@metadata}"
  end

  alias_method :to_full_version, :to_str

  # @return [SemanticVersion] a new version object with the same values.
  def to_version
    SemanticVersion.new(self.to_full_version)
  end

  # @return [String] a human-readable representation of the version object.
  def inspect
    @version.inspect
  end

  # Comparable base method.
  # @param (see #initialize)
  # @return [-1, 0, 1]
  def <=>(version)
    compare_to = SemanticVersion.new(version)
    comparison = self.to_a <=> compare_to.to_a
    case comparison
    when 0 then (self.prerelease? ? -1 : 0) - (compare_to.prerelease? ? -1 : 0)
    else comparison
    end
  end
end
