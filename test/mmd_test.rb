# encoding: UTF-8
require_relative 'test_helper'
require 'mmd'

# Mocks
class MockEnv < Minitest::Mock
  def initialize(value = nil)
    super()
    2.times do expect :[], value, ['MULTIMARKDOWN'] end
  end
end

class MockShellRunner < Minitest::Mock
  def initialize(path_bins, env_bin = nil)
    super()
    expect :new, self
    expect :run_command, path_bins.map(&:path).join($/), ['bash', '-lc', 'which -a multimarkdown']
    all_bins = env_bin.nil? ? path_bins : [env_bin] | path_bins
    all_bins.select {|b| b.executable }.each do |b| expect :run_command, "MultiMarkdown version #{b.version}", [b.path, '-v'] end
  end
end

class MockFile < Minitest::Mock
  def initialize(bins)
    super()
    bins.each do |b| expect :executable?, b.executable, [b.path] end
  end
end

# Stubs
Struct.new('Bin', :path, :executable, :version) do
  def ok?
    executable && version >= MultiMarkdownParser::MINIMUM_VERSION
  end
end

Struct.new('File', :path)

class TestMultiMarkdownParser < Minitest::Test
  # default setup: ENV unset and at least one compatible binary + one incompatible binary in PATH
  def setup
    i = 1
    @bins = [].tap {|a|
      until a.select {|b| b.ok? }.count >= 1 && a.reject {|b| b.ok? }.count >= 1 do
        i += rand(9)+1
        v  = "#{('3.0'..'5.1').to_a.sample}.#{rand(9)}"
        a << Struct::Bin.new("/rand/#{i}/multimarkdown", [true, false].sample, v)
      end
    }
    @good = @bins.select {|b| b.ok? }
    @best = @good.find   {|b| b.version = @good.map(&:version).sort.last }

    @meta_keys = ['title', 'tags', 'notebook', 'author', 'date created', 'permalink']

    @env      = MockEnv.new
    @runner   = MockShellRunner.new(@bins)
    @file_lib = MockFile.new(@bins)

    MultiMarkdownParser.stub_const(:ENV, @env) do
      MultiMarkdownParser.stub_const(:ShellRunner, @runner) do
        MultiMarkdownParser.stub_const(:File, @file_lib) do
          @mmd = MultiMarkdownParser.new
        end
      end
    end

    @env.verify
    @runner.verify
    @file_lib.verify
  end

  # .new() raises a RuntimeError if no MMD binary is found
  def test_new_raises_error_if_no_executable_mmd_is_found
    runner = MockShellRunner.new([Struct::Bin.new('', false, '0.0.0')])
    MultiMarkdownParser.stub_const(:ShellRunner, runner) do
      assert_raises(RuntimeError) { MultiMarkdownParser.new }
    end
    runner.verify
  end

  # else the best MMD binary found in PATH is used
  def test_new_completes_using_best_executable_found_in_path
    assert_equal @best.path, @mmd.bin
  end

  # values in MULTIMARKDOWN are used only if qualifying as best binary
  def test_new_completes_using_env_setting_if_best
    [@best, @bins.reject {|b| b.ok? }.sample].each do |env_bin|
      env      = MockEnv.new(env_bin.path)
      runner   = MockShellRunner.new(@bins, env_bin)
      file_lib = MockFile.new([env_bin] | @bins)

      MultiMarkdownParser.stub_const(:ENV, env) do
        MultiMarkdownParser.stub_const(:ShellRunner, runner) do
          MultiMarkdownParser.stub_const(:File, file_lib) do
            assert_equal @best.path, MultiMarkdownParser.new.bin
          end
        end
      end

      env.verify
      runner.verify
      file_lib.verify
    end
  end

  # String conversions return @bin’s path
  def test_bin_as_string_is_path
    assert_equal @mmd.bin, @mmd.to_path
    assert_equal @mmd.bin, @mmd.to_s
    assert_equal @mmd.bin, @mmd.to_str
  end

  # relevant Pathname properties of @bin are exposed
  def test_pathname_properties_exposed
    [
      :expand_path, :realpath, :realdirpath, :dirname, :basename, :parent,
      :size, :stat, :atime, :ctime, :owned?, :grpowned?, :symlink?, :readlink
    ].each {|method| assert_respond_to @mmd, method }
  end

  # version() returns a SemanticVersion
  def test_correct_semantic_version_retrieved
    assert_instance_of SemanticVersion, @mmd.version
    assert_equal  SemanticVersion.new(@best.version), @mmd.version.to_s
  end

  # retrieve all metadata in source file if MMD supports the '-m' option
  def test_loads_all_metadata_if_supported_and_fallback_set_if_not
    source  = Struct::File.new('/rand/new/source.md')
    fb_keys = @meta_keys.sample(3)

    [
      { MultiMarkdownParser::METADATA_VERSION => @meta_keys},
      {(MultiMarkdownParser::MINIMUM_VERSION...MultiMarkdownParser::METADATA_VERSION).to_a.sample => fb_keys}
    ].each do |set|
      version  = set.keys.first
      keys     = set.values.first
      bin      = Struct::Bin.new('/rand/use/multimarkdown', true, version)
      env      = MockEnv.new
      file_lib = MockFile.new([bin])

      runner   = MockShellRunner.new([bin]);
      runner.expect :run_command, keys.join($/), [bin.path, '-m', source.path] if version >= MultiMarkdownParser::METADATA_VERSION
      keys.each {|k| runner.expect :run_command, "Value for #{k} metadata.", [bin.path, '-e', k, source.path] }

      MultiMarkdownParser.stub_const(:ENV, env) do
        MultiMarkdownParser.stub_const(:ShellRunner, runner) do
          MultiMarkdownParser.stub_const(:File, file_lib) do
            mmd      = MultiMarkdownParser.new
            metadata = mmd.load_file_metadata(source, *fb_keys)
            assert_instance_of Hash, metadata
            assert_equal keys, metadata.keys
            assert_equal keys.count, metadata.select {|k,v| v == "Value for #{k} metadata." }.count
          end
        end
      end

      env.verify
      runner.verify
      file_lib.verify
    end
  end

  # pure stub test for the Markdown conversion MMD command
  def test_generates_correct_mmd_command_for_conversion
    source = Struct::File.new('/rand/new/source.md')

    out_formats = [:html, :latex, :beamer, :memoir, :odf, :opml]
    out_formats.each do |format|
      out_file = Struct::File.new('/rand/new/source.md')
      env      = MockEnv.new
      file_lib = MockFile.new(@bins)

      runner   = MockShellRunner.new(@bins)
      runner.expect :run_command, '', [@best.path, '-t', String(format), source.path]                      # to stdout
      runner.expect :run_command, '', [@best.path, '-t', String(format), '-o', out_file.path, source.path] # to file

      MultiMarkdownParser.stub_const(:ENV, env) do
        MultiMarkdownParser.stub_const(:ShellRunner, runner) do
          MultiMarkdownParser.stub_const(:File, file_lib) do
            mmd = MultiMarkdownParser.new
            mmd.convert_file(source, to_format: format)                        # to stdout
            mmd.convert_file(source, to_format: format, output_file: out_file) # to file
          end
        end
      end

      env.verify
      runner.verify
      file_lib.verify
    end
   end
end
