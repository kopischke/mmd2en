# encoding: UTF-8
require_relative 'test_helper'
require 'semantic_version'

class TestSemanticVersion < Minitest::Test
  def setup
    @test_hash = {major: rand(1..9), minor: rand(1..20), patch: rand(1..100)}
    @test_ary  = @test_hash.values
    @test_str  = @test_ary.join('.')
    @test_ver  = SemanticVersion.new("#{@test_str}-alpha4")
  end

  def test_parses_a_full_string
    v = SemanticVersion.new('1.5.3')
    assert_equal 1, v.major
    assert_equal 5, v.minor
    assert_equal 3, v.patch
  end

  def test_ignores_build_info
    v = SemanticVersion.new('4.12.9-alpha')
    assert_equal 4,  v.major
    assert_equal 12, v.minor
    assert_equal 9,  v.patch
  end

  def test_parses_a_partial_string
    v = SemanticVersion.new('2.1')
    assert_equal 2, v.major
    assert_equal 1, v.minor
    assert_equal 0, v.patch

    v = SemanticVersion.new('3')
    assert_equal 3, v.major
    assert_equal 0, v.minor
    assert_equal 0, v.patch
  end

  def test_parses_a_numeric
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

  def test_converts_to_string_explicitly
    version = '12.0.3'
    assert_equal @test_str, @test_ver.to_s
    assert_equal "Version #{version}.", "Version #{SemanticVersion.new(version)}."
  end

  def test_converts_to_array
    assert_equal @test_ary, @test_ver.to_a
    assert_equal @test_ary, @test_ver.to_ary
  end

  def test_converts_to_hash
    assert_equal(@test_hash, @test_ver.to_h)
    assert_equal(@test_hash, @test_ver.to_hash)
  end

  def test_raises_error_if_passed_invalid_version_representation
    assert_raises(ArgumentError) { SemanticVersion.new('1.2a')    }
    assert_raises(ArgumentError) { SemanticVersion.new([1, 2, 0]) }
    assert_raises(ArgumentError) { SemanticVersion.new('')        }
    assert_raises(ArgumentError) { SemanticVersion.new(nil)       }
  end

  def test_implements_comparable
    Comparable.instance_methods.each do |method| assert_respond_to @test_ver, method end
  end

  def test_compares_to_other_versions
    va = SemanticVersion.new('0.3.9-ab')
    vb = SemanticVersion.new('0.3.9')
    vc = SemanticVersion.new('0.3.7+build110')
    assert_equal  0, (va <=> vb)
    assert_equal  0, (vb <=> va)
    assert_equal  1, (va <=> vc)
    assert_equal -1, (vc <=> va)
    assert_equal  1, (vb <=> vc)
    assert_equal -1, (vc <=> va)
  end
end
