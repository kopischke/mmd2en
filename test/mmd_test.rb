# encoding: UTF-8
require_relative 'test_helper'
require 'mmd'

class MockEnv < Minitest::Mock
  def initialize(value = nil)
    super()
    2.times { expect :[], value, ['MULTIMARKDOWN'] }
  end
end

class MockShellRunner < Minitest::Mock
  def initialize(all_bin_paths, use_bin, use_version = nil)
    super()
    expect :new, self
    expect :run_command, all_bin_paths.join($/), ['which', '-a', 'multimarkdown']
    version_info = use_version ? "MultiMarkdown version #{use_version}" : ''
    expect :run_command, version_info, [use_bin, '-v']
  end
end

class MockFile < Minitest::Mock
  def initialize(all_bins, use_bin, env_set = false)
    super()
    env_set and expect :expand_path, all_bins.keys.first, [all_bins.keys.first]
    all_bins.each do |k,v|
      expect :executable?, v, [k]
      break if k == use_bin
    end
  end
end

class TestMultiMarkdownParser < Minitest::Test
  # default: ENV binary unset and two out of a random number of MMD binaries in PATH executable
  def setup
    @bins = {}; i = 0
    until (@bins.select {|k,v| v == true }.count == 2) do
      @bins["/rand/#{i += 1}/multimarkdown"] = rand(2) == 0
    end
    @bin  = @bins.find {|k,v| v == true }.first

    @version   = '4.3.1'
    @meta_keys = ['title', 'tags', 'notebook', 'author', 'date created', 'permalink']

    @env    = MockEnv.new
    @runner = MockShellRunner.new(@bins.keys, @bin, @version)
    @filer  = MockFile.new(@bins, @bin)

    MultiMarkdownParser.stub_const(:ENV, @env) do
      MultiMarkdownParser.stub_const(:ShellRunner, @runner) do
        MultiMarkdownParser.stub_const(:File, @filer) do
          @mmd = MultiMarkdownParser.new
        end
      end
    end

    @env.verify
    @runner.verify
    @filer.verify
  end

  # .new() raises a RuntimeError if no MMD executable is found
  def test_new_raises_error_if_no_executable_mmd_is_found
    runner = Minitest::Mock.new
    runner.expect :new, runner
    runner.expect :run_command, '', ['which', '-a', 'multimarkdown']

    MultiMarkdownParser.stub_const(:ShellRunner, runner) do
      assert_raises(RuntimeError) { MultiMarkdownParser.new }
    end

    runner.verify
  end

  # else the first executable MMD binary found in PATH is used
  def test_new_completes_using_first_executable_found_in_path
    assert_equal @bin, @mmd.bin
  end

  # but values in MULTIMARKDOWN mapping to an executable MMD binary are preferred
  def test_new_completes_using_valid_env_setting
    envbin = '/env/rand/multimarkdown'

    env    = MockEnv.new(envbin)
    runner = MockShellRunner.new(@bins.keys, envbin, @version)
    filer  = MockFile.new({envbin => true}.merge(@bins), envbin, true)

    MultiMarkdownParser.stub_const(:ENV, env) do
      MultiMarkdownParser.stub_const(:ShellRunner, runner) do
        MultiMarkdownParser.stub_const(:File, filer) do
          assert_equal envbin, MultiMarkdownParser.new.bin
        end
      end
    end

    env.verify
    runner.verify
    filer.verify
  end

  # tho values in MULTIMARKDOWN that do not map to an executable binary are ignored
  def test_new_completes_ignoring_invalid_env_setting
    envbin = '/env/rand/multimarkdown'

    env    = MockEnv.new(envbin)
    runner = MockShellRunner.new(@bins.keys, @bin, @version)
    filer  = MockFile.new({envbin => false}.merge(@bins), @bin, true)

    MultiMarkdownParser.stub_const(:ENV, env) do
      MultiMarkdownParser.stub_const(:ShellRunner, runner) do
        MultiMarkdownParser.stub_const(:File, filer) do
          assert_equal @bin, MultiMarkdownParser.new.bin
        end
      end
    end

    env.verify
    runner.verify
    filer.verify
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

  # version() returns a SemanticVersion if multimarkdown supports the -v option'
  def test_semantic_version_retrieved_if_v_opt_supported
    assert_instance_of SemanticVersion, @mmd.version
    assert_equal  @version, @mmd.version.to_s
  end

  # else version() returns nil
  def test_nil_version_retrieved_if_v_opt_not_supported
    env    = MockEnv.new
    runner = MockShellRunner.new(@bins.keys, @bin)
    filer  = MockFile.new(@bins, @bin)

    MultiMarkdownParser.stub_const(:ENV, env) do
      MultiMarkdownParser.stub_const(:ShellRunner, runner) do
        MultiMarkdownParser.stub_const(:File, filer) do
          mmd = MultiMarkdownParser.new
          assert_nil mmd.version
        end
      end
    end

    env.verify
    runner.verify
    filer.verify
  end

  # retrieve all metadata in source file if MMD supports the '-m' option
  def test_loads_all_metadata_if_m_opt_supported
    @meta_keys   = ['title', 'tags', 'notebook', 'author', 'date created', 'permalink']

    source_path = '/rand/new/source.md'
    source_file = Minitest::Mock.new
    (@meta_keys.count + 1).times { source_file.expect :path, source_path }

    env    = MockEnv.new
    filer  = MockFile.new(@bins, @bin)

    runner = MockShellRunner.new(@bins.keys, @bin, @version)
    runner.expect :run_command, @meta_keys.join($/), [@bin, '-m', source_path]
    @meta_keys.each {|k| runner.expect :run_command, "Value for #{k} metadata.", [@bin, '-e', k, source_path] }

    MultiMarkdownParser.stub_const(:ENV, env) do
      MultiMarkdownParser.stub_const(:ShellRunner, runner) do
        MultiMarkdownParser.stub_const(:File, filer) do
          mmd      = MultiMarkdownParser.new
          metadata = mmd.load_file_metadata(source_file, @meta_keys.sample(3))
          assert_instance_of Hash, metadata
          assert_equal @meta_keys, metadata.keys
          assert_equal @meta_keys.count, metadata.select {|k,v| v == "Value for #{k} metadata." }.count
        end
      end
    end

    source_file.verify
    env.verify
    runner.verify
    filer.verify
  end

  # but only metadata keys passed to 'load_file_metadata' if not
  def test_loads_fallback_key_metadata_if_m_opt_not_supported
    use_keys    = @meta_keys.sample(3)

    source_path = '/rand/new/source.md'
    source_file = Minitest::Mock.new
    (use_keys.count + 1).times { source_file.expect :path, source_path }

    env    = MockEnv.new
    filer  = MockFile.new(@bins, @bin)

    runner = MockShellRunner.new(@bins.keys, @bin, nil) # no version info => no -m call
    use_keys.each {|k| runner.expect :run_command, "Value for #{k} metadata.", [@bin, '-e', k, source_path] }

    MultiMarkdownParser.stub_const(:ENV, env) do
      MultiMarkdownParser.stub_const(:ShellRunner, runner) do
        MultiMarkdownParser.stub_const(:File, filer) do
          mmd = MultiMarkdownParser.new
          metadata = mmd.load_file_metadata(source_file, *use_keys)
          assert_instance_of Hash, metadata
          assert_equal use_keys, metadata.keys
          assert_equal use_keys.count, metadata.select {|k,v| v == "Value for #{k} metadata." }.count
        end
      end
    end

    source_file.verify
    env.verify
    runner.verify
    filer.verify
  end

  # pure stub test for the Markdown conversion MMD command
  def test_generates_correct_mmd_command_for_conversion
    source_path = '/rand/new/source.md'

    output_formats = [:html, :latex, :beamer, :memoir, :odf, :opml]
    output_formats.each do |format|
      source_file = Minitest::Mock.new
      2.times { source_file.expect :path, source_path }

      output_path = "/out/new/result.#{format}"
      output_file =  Minitest::Mock.new
      output_file.expect :path, output_path

      env    = MockEnv.new
      filer  = MockFile.new(@bins, @bin)
      runner = MockShellRunner.new(@bins.keys, @bin)
      runner.expect :run_command, '', [@bin, '-t', String(format), source_path] # to stdout
      runner.expect :run_command, '', [@bin, '-t', String(format), '-o', output_path, source_path] # to file

      MultiMarkdownParser.stub_const(:ENV, env) do
        MultiMarkdownParser.stub_const(:ShellRunner, runner) do
          MultiMarkdownParser.stub_const(:File, filer) do
            mmd = MultiMarkdownParser.new
            mmd.convert_file(source_file, to_format: format) # to stdout
            mmd.convert_file(source_file, to_format: format, output_file: output_file) # to file
          end
        end
      end

      source_file.verify
      output_file.verify
      env.verify
      runner.verify
      filer.verify
    end
  end
end
