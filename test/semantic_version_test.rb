# encoding: UTF-8
require_relative 'test_helper'
require 'semantic_version'

class TestSemanticVersion < Minitest::Test
  def setup
    @hash       = {major: rand(1..9), minor: rand(1..20), patch: rand(1..100)}
    @array      = @hash.values
    @string     = @array.join('.')
    @prerelease = '-alpha.4'
    @build_info = '+rc.5.21'
    @version    = SemanticVersion.new("#{@string}")
  end

  def test_class_exposes_version_parts_contant
    assert_instance_of Array, SemanticVersion::VERSION_PARTS
    SemanticVersion::VERSION_PARTS.each do |part| assert_instance_of Symbol, part end
  end

  def test_class_exposes_version_constants
    [SemanticVersion::VERSION, SemanticVersion::SPEC_VERSION].each do |const|
      assert_instance_of String, const
      refute_empty       const
    end
  end

  def test_exposes_to_version_methods
    assert_respond_to  @version, :to_version
    assert_respond_to  @version, :to_full_version
    assert_respond_to  @version, :to_gem_version
  end

  def test_exposes_bump_methods
    assert_respond_to @version, :bump
    assert_respond_to @version, :bump!
  end

  def test_exposes_prerelease_test
    assert_respond_to @version, :prerelease?
  end

  def test_exposes_metadata_accessor
    assert_respond_to @version, :metadata
    assert_respond_to @version, :metadata=
  end

  def test_new_parses_a_full_string
    v = SemanticVersion.new(@string)
    @hash.keys.each do |key| assert_equal @hash[key], v.send(key) end
    assert_empty v.metadata
    refute       v.prerelease?

    v = SemanticVersion.new("#{@string}#{@prerelease}")
    @hash.keys.each do |key| assert_equal @hash[key], v.send(key) end
    assert_equal @prerelease[1..-1], v.metadata
    assert       v.prerelease?

    v = SemanticVersion.new("#{@string}#{@build_info}")
    @hash.keys.each do |key| assert_equal @hash[key], v.send(key) end
    assert_equal @build_info[1..-1], v.metadata
    refute       v.prerelease?
  end

  def test_new_parses_a_partial_string
    v = SemanticVersion.new([@hash[:major], @hash[:minor]].join('.'))
    [:major, :minor].each do |key| assert_equal @hash[key], v.send(key) end
    assert_equal 0, v.patch
    assert_empty v.metadata
    refute       v.prerelease?

    v = SemanticVersion.new(String(@hash[:major]))
    assert_equal @hash[:major], v.major
    [:minor, :patch].each do |key| assert_equal 0, v.send(key)end
    assert_empty v.metadata
    refute       v.prerelease?

    v = SemanticVersion.new("#{@hash[:major]}#{@prerelease}")
    assert_equal @hash[:major], v.major
    [:minor, :patch].each do |key| assert_equal 0, v.send(key)end
    assert_equal @prerelease[1..-1], v.metadata
    assert       v.prerelease?

    v = SemanticVersion.new("#{@hash[:major]}#{@build_info}")
    assert_equal @hash[:major], v.major
    [:minor, :patch].each do |key| assert_equal 0, v.send(key)end
    assert_equal @build_info[1..-1], v.metadata
    refute       v.prerelease?
  end

  def test_new_parses_a_numeric
    v = SemanticVersion.new(0.7)
    assert_equal 0, v.major
    assert_equal 7, v.minor
    assert_equal 0, v.patch

    v = SemanticVersion.new(12)
    assert_equal 12, v.major
    assert_equal 0,  v.minor
    assert_equal 0,  v.patch

    v = SemanticVersion.new(0x12)
    assert_equal 18, v.major
    assert_equal 0,  v.minor
    assert_equal 0,  v.patch
  end

  def test_converts_to_string
    assert_equal @string, @version.to_s
    assert_equal @string, @version.to_gem_version
    assert_equal "#{@string}#{@info}", @version.to_str
    assert_equal "#{@string}#{@info}", @version.to_full_version
  end

  def test_converts_to_array
    assert_equal @array, @version.to_a
    assert_equal @array, @version.to_ary
  end

  def test_converts_to_hash
    assert_equal(@hash, @version.to_h)
    assert_equal(@hash, @version.to_hash)
  end

  def test_raises_error_if_passed_invalid_version_representation
    assert_raises(ArgumentError) { SemanticVersion.new('1.2.0a')  }
    assert_raises(ArgumentError) { SemanticVersion.new([1, 2, 0]) }
    assert_raises(ArgumentError) { SemanticVersion.new('')        }
    assert_raises(ArgumentError) { SemanticVersion.new(nil)       }
  end

  def test_implements_comparable
    Comparable.instance_methods.each do |method| assert_respond_to @version, method end
  end

  def test_compares_to_other_versions
    va = SemanticVersion.new(@string)
    vb = SemanticVersion.new(@string).bump!
    vc = SemanticVersion.new(@string).bump!(:minor)
    vd = SemanticVersion.new(@string).bump!(:major)
    assert_equal(-1, va <=> vb)
    assert_equal(-1, vb <=> vc)
    assert_equal(-1, vc <=> vd)
  end

  def test_compares_to_string_and_numeric
    base    = "#{@hash[:major]}.#{@hash[:minor]}".gsub(/0$/, '') # trailing zeroes get lost in #to_f
    version = SemanticVersion.new(base)
    assert_equal 0, version <=> base
    assert_equal 0, version <=> base.to_f
  end

  def test_comparison_minds_prerelease
    va = SemanticVersion.new("#{@string}#{@prerelease}")
    vb = SemanticVersion.new(@string)
    assert_equal(-1, va <=> vb)
  end

  def test_comparison_ignores_build_metadata
    va = SemanticVersion.new(@string)
    vb = SemanticVersion.new("#{@string}#{@build_info}")
    assert_equal 0, (va <=> vb)
  end

  def test_to_version_returns_new_version_object
    assert_instance_of SemanticVersion, @version.to_version
    refute_equal       @version.to_version.bump!, @version
  end

  def test_bump_bumps_version_parts
    assert_equal @version.bump, @version.bump(:patch)
    @hash.keys.each do |part|
      bumped_hash = @hash.dup
      bumped_hash[part]  += 1
      bumped_hash[:patch] = 0 if part == :minor || part == :major
      bumped_hash[:minor] = 0 if part == :major

      assert_equal bumped_hash, @version.bump(part).to_hash
      assert_equal @hash,       @version.to_hash # unmodified object

      bumped = SemanticVersion.new(@string).bump!(part)
      assert_equal bumped_hash, bumped.to_hash
      assert_empty              bumped.metadata
    end
  end

  def test_bump_voids_metadata
    assert_empty SemanticVersion.new("#{@string}#{@prerelease}").bump!.metadata
  end

  def test_release_voids_prerelease_info
    @version.metadata = @prerelease
    @version.release!
    assert_empty @version.metadata
    refute       @version.prerelease?

    @version.metadata = @build_info
    @version.release!
    refute_empty @version.metadata
    refute       @version.prerelease?
  end

  def test_metadata_setter_fails_if_metadata_invalid
    @version.metadata = @build_info
    assert_equal @build_info[1..-1], @version.metadata
    assert_raises (ArgumentError) { @version.metadata = 'foobar' }
  end
end
