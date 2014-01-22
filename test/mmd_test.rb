# encoding: UTF-8
require_relative 'test_helper'
require 'mmd'

module Mocks
  class ShellRunner < Minitest::Mock
    # Note: all `(using_)?bin`arguments expect a Stub::Bin
    def initialize
      super()
      expect :new, self
    end

    def expect_shell_query_returning(*bins)
      command = 'echo $MULTIMARKDOWN; which -a multimarkdown'
      expect :run_command, bins.map(&:path).join($/), ['bash', '-lc', command]
    end

    def expect_version_query_for(*bins)
      bins.select {|b| b.executable }.each do |b|
        expect :run_command, "MultiMarkdown version #{b.version}", [b.path, '-v']
      end
    end

    def expect_conversion_command_for(file, using_bin, to_format: :html, to_file: false)
      options = ['-t', to_format.to_s]
      options.push('-o', to_file) if to_file
      expect :run_command, '', [using_bin.path, *options, file]
    end

    def expect_metadata_listing_query_for(file, using_bin, *return_keys)
      expect :run_command, return_keys.join($/), [using_bin.path, '-m', file]
    end

    def expect_metadata_key_query_for(key, file, using_bin, returns)
      expect :run_command, returns, [using_bin.path, '-e', key, file]
    end
  end
end

module Stubs
  # `multimarkdown` binary with metadata
  Bin = Struct.new(:path, :executable, :version) do
    def ok?
     self.executable && self.version >= MultiMarkdownParser::MINIMUM_VERSION
    end
  end

  # File.method stubs
  File = Struct.new(:path) do
    def self.executable?(path)
      path.match('/true/')
    end

    def self.expand_path(path)
      ::File.expand_path(path)
    end
  end

  # stub_const call wrapper for nested stubbed runner and File lib
  def self.with_runner(runner, &block)
    MultiMarkdownParser.stub_const(:ShellRunner, runner) do
      MultiMarkdownParser.stub_const(:File, Stubs::File) do
        block.call
      end
    end
  end
end

class TestMultiMarkdownParser < Minitest::Test
  def setup
    @bins = [] # available binaries
    until @bins.select {|b| b.ok? }.count >= 1 && @bins.reject {|b| b.ok? }.count >= 1 do
      index ||= 0
      exec    = [true, false].sample
      version = "#{('3.0'..'5.1').to_a.sample}.#{rand(9)}"
      path    = "/stub/#{index += 1}/#{version}/#{exec}/multimarkdown"
      @bins  << Stubs::Bin.new(path, exec, version)
    end

    # specific @bins subset and a designated dud
    @exec = @bins.select {|bin| bin.executable }
    @good = @bins.select {|bin| bin.ok? }
    @best = @good.max_by {|bin| bin.version }
    @dud  = Stubs::Bin.new('', false, '0.0.0')

    # metadata key selection
    @meta_keys = ['title', 'tags', 'notebook', 'author', 'date created', 'permalink']

    # file source path
    @source   = '/stub/file/source.md'

    # blank mock ShellRunner instance
    @runner   = Mocks::ShellRunner.new

    # plain vanilla MultiMarkdownParser instance
    runner    = Mocks::ShellRunner.new
    runner.expect_shell_query_returning(@best)
    runner.expect_version_query_for(@best)
    Stubs.with_runner(runner) do
      @mmd = MultiMarkdownParser.new
    end
  end

  def test_exposes_pathname_instance_methods
    Pathname.instance_methods.each do |m| assert_respond_to @mmd, m end
  end

  def test_exposes_version_reader
    assert_respond_to @mmd, :version
    refute_respond_to @mmd, :version=
  end

  def test_version_returns_correct_semantic_version
    assert_instance_of String, @mmd.version
    assert_equal       @best.version, @mmd.version
  end

  def test_new_completes_using_best_binary_found
    @runner.expect_shell_query_returning(*@bins)
    @runner.expect_version_query_for(*@exec)
    Stubs.with_runner(@runner) do
      assert_equal @best.path, MultiMarkdownParser.new.to_path
    end
    @runner.verify
  end

  def test_new_ignores_empty_env_settings
    @runner.expect_shell_query_returning(@dud, @best)
    @runner.expect_version_query_for(@best)
    Stubs.with_runner(@runner) do
      assert_equal @best.path, MultiMarkdownParser.new.to_path
    end
    @runner.verify
  end

  def test_new_raises_error_if_no_binary_is_found
    @runner.expect_shell_query_returning(@dud)
    Stubs.with_runner(@runner) do
      assert_raises(RuntimeError) { MultiMarkdownParser.new }
    end
    @runner.verify
  end

  def test_load_file_metadata_queries_all_keys_if_m_supported
    fallback = @meta_keys.sample(3)
    keys     = @meta_keys.sample(4)
    bin      = Stubs::Bin.new(@exec.sample.path, true, MultiMarkdownParser::BASELINE_VERSION)

    @runner.expect_shell_query_returning(bin)
    @runner.expect_version_query_for(bin)
    @runner.expect_metadata_listing_query_for(@source, bin, *keys)
    keys.each do |key| @runner.expect_metadata_key_query_for(key, @source, bin, "Value for #{key} metadata.") end

    Stubs.with_runner(@runner) do
      mmd  = MultiMarkdownParser.new
      data = mmd.load_file_metadata(@source, *fallback)
      assert_instance_of Hash, data
      assert_equal       keys, data.keys
      assert_equal keys.count, data.select {|k,v| v == "Value for #{k} metadata." }.count
    end

    @runner.verify
  end

  def test_load_file_metadata_queries_fallback_if_m_unsupported
    fallback = @meta_keys.sample(3)
    keys     = @meta_keys
    bin      = Stubs::Bin.new(@exec.sample.path, true, MultiMarkdownParser::MINIMUM_VERSION)

    @runner.expect_shell_query_returning(bin)
    @runner.expect_version_query_for(bin)
    fallback.each do |key| @runner.expect_metadata_key_query_for(key, @source, bin, "Value for #{key} metadata.") end

    Stubs.with_runner(@runner) do
      mmd  = MultiMarkdownParser.new
      data = mmd.load_file_metadata(@source, *fallback)
      assert_instance_of     Hash, data
      assert_equal       fallback, data.keys
      assert_equal fallback.count, data.select {|k,v| v == "Value for #{k} metadata." }.count
    end

    @runner.verify
  end

  def test_load_file_returns_empty_hash_on_empty_m_list
    bin = Stubs::Bin.new(@exec.sample.path, true, MultiMarkdownParser::BASELINE_VERSION)

    @runner.expect_shell_query_returning(bin)
    @runner.expect_version_query_for(bin)
    @runner.expect_metadata_listing_query_for(@source, bin, "")
    Stubs.with_runner(@runner) do
      mmd  = MultiMarkdownParser.new
      data = mmd.load_file_metadata(@source, @meta_keys.sample(3))
      assert_instance_of Hash, data
      assert_empty       data
    end
    @runner.verify
  end

  def test_convert_file_generates_correct_mmd_command
    output  = @source.sub(/md$/, 'out')
    formats = [:html, :latex, :beamer, :memoir, :odf, :opml]

    @runner.expect_shell_query_returning(@best)
    @runner.expect_version_query_for(@best)

    Stubs.with_runner(@runner) do
      mmd = MultiMarkdownParser.new
      formats.each do |format|
        @runner.expect_conversion_command_for(@source, @best, to_format: format)
        mmd.convert_file(@source, to_format: format)

        @runner.expect_conversion_command_for(@source, @best, to_file: output, to_format: format)
        mmd.convert_file(@source, to_format: format, output_file: output)
      end
    end
    @runner.verify
  end
end
