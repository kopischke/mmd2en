# encoding: UTF-8
require_relative 'test_helper'
require 'semver'

class TestSemanticVersion < Minitest::Test
  def test_parses_a_full_string
    v = SemanticVersion.new('1.5.3')
    assert_equal 1, v[:major]
    assert_equal 5, v[:minor]
    assert_equal 3, v[:patch]
  end

  def test_ignores_build_info
    v = SemanticVersion.new('4.12.9-alpha')
    assert_equal 4,  v[:major]
    assert_equal 12, v[:minor]
    assert_equal 9,  v[:patch]
  end

  def test_parses_a_partial_string
    v = SemanticVersion.new('2.1')
    assert_equal 2, v[:major]
    assert_equal 1, v[:minor]
    assert_equal 0, v[:patch]

    v = SemanticVersion.new('3')
    assert_equal 3, v[:major]
    assert_equal 0, v[:minor]
    assert_equal 0, v[:patch]
  end

  def test_parses_a_numeric
    v = SemanticVersion.new(0.7)
    assert_equal 0, v[:major]
    assert_equal 7, v[:minor]
    assert_equal 0, v[:patch]

    v = SemanticVersion.new(12)
    assert_equal 12, v[:major]
    assert_equal 0,  v[:minor]
    assert_equal 0,  v[:patch]

    v = SemanticVersion.new(0x12)
    assert_equal 18, v[:major]
    assert_equal 0,  v[:minor]
    assert_equal 0,  v[:patch]
  end

  def test_converts_to_a_string_explicitly_and_implicitly
    version = '12.0.3'
    assert_equal '9.12.4', SemanticVersion.new('9.12.4-alpha4').to_s
    assert_equal "Version #{version}.", ('Version ' << SemanticVersion.new(version) << '.')
  end

  def test_raises_an_error_if_passed_an_invalid_version_representation
    assert_raises(ArgumentError) { SemanticVersion.new('1.2a')    }
    assert_raises(ArgumentError) { SemanticVersion.new([1, 2, 0]) }
    assert_raises(ArgumentError) { SemanticVersion.new('')        }
    assert_raises(ArgumentError) { SemanticVersion.new(nil)       }
  end

  def expose_keys_values_and_each_methods_correctly
    v = SemanticVersion.new('0.8.11')
    assert_equal [:major, :minor, :patch], v.keys
    assert_equal [0, 8, 11], v.values
    assert_instance_of v.each, Enumerator
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

  def test_implements_comparable
    va = SemanticVersion.new('24.22.1-alpha+build123')
    vb = SemanticVersion.new('24.22.1')
    vc = SemanticVersion.new(24.22)
    assert_operator va, :>=, vb
    assert_operator va, :<=, vb
    refute_operator va, :>,  vb
    refute_operator va, :>,  vb
    assert_operator va, :==, vb
    refute_operator va, :!=, vb
    assert_operator va, :>=, vc
    assert_operator va, :>=, vc
    refute_operator va, :<=, vc
    assert_operator va, :> , vc
    refute_operator va, :< , vc
    refute_operator va, :==, vc
    assert_operator va, :!=, vc
  end
end
