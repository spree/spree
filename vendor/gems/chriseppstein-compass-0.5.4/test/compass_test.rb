require  File.dirname(__FILE__)+'/test_helper'
require 'fileutils'
require 'compass'

class CompassTest < Test::Unit::TestCase
  include Compass::TestCaseHelper
  def setup
    setup_fixtures :blueprint, :yui, :empty
    @original_options = Sass::Plugin.options
  end
  
  def setup_fixtures(*folders)
    folders.each do |folder|
      FileUtils.mkdir_p stylesheet_fixtures(folder)
      mkdir_clean tempfile_loc(folder)
    end
  end

  def teardown
    teardown_fixtures :blueprint, :yui, :empty
    Sass::Plugin.options = @original_options
  end

  def teardown_fixtures(*folders)
    folders.each do |folder|
      FileUtils.rm_rf tempfile_loc(folder)
    end
  end

  def test_blueprint_generates_no_files
    with_templates(:empty) do
      Dir.new(tempfile_loc(:empty)).each do |f|
        fail "This file should not have been generated: #{f}" unless f == "." || f == ".."
      end
    end
  end

  def test_blueprint
    with_templates(:blueprint) do
      each_css_file(tempfile_loc(:blueprint)) do |css_file|
        assert_no_errors css_file, :blueprint
      end
      assert_renders_correctly :typography
    end
  end
  def test_yui
    with_templates('yui') do
      each_css_file(tempfile_loc('yui')) do |css_file|
        assert_no_errors css_file, 'yui'
      end
      assert_renders_correctly :mixins
    end
  end
  def test_compass
    with_templates('compass') do
      each_css_file(tempfile_loc('compass')) do |css_file|
        assert_no_errors css_file, 'compass'
      end
      assert_renders_correctly :reset, :layout, :utilities
    end
  end
  private
  def assert_no_errors(css_file, folder)
    file = css_file[(tempfile_loc(folder).size+1)..-1]
    msg = "Syntax Error found in #{file}. Results saved into #{save_loc(folder)}/#{file}"
    assert_equal 0, open(css_file).readlines.grep(/Sass::SyntaxError/).size, msg
  end
  def assert_renders_correctly(*arguments)
    options = arguments.last.is_a?(Hash) ? arguments.pop : {}
    for name in arguments
      actual_result_file = "#{tempfile_loc(@current_template_folder)}/#{name}.css"
      expected_result_file = "#{result_loc(@current_template_folder)}/#{name}.css"
      actual_lines = File.read(actual_result_file).split("\n")
      expected_lines = File.read(expected_result_file).split("\n")
      expected_lines.zip(actual_lines).each_with_index do |pair, line|
        message = "template: #{name}\nline:     #{line + 1}"
        assert_equal(pair.first, pair.last, message)
      end
      if expected_lines.size < actual_lines.size
        assert(false, "#{actual_lines.size - expected_lines.size} Trailing lines found in #{actual_result_file}.css: #{actual_lines[expected_lines.size..-1].join('\n')}")
      end
    end
  end
  def with_templates(folder)
    old_template_loc = Sass::Plugin.options[:template_location]
    Sass::Plugin.options[:template_location] = if old_template_loc.is_a?(Hash)
      old_template_loc.dup
    else
      Hash.new
    end
    @current_template_folder = folder
    begin
      Sass::Plugin.options[:template_location][template_loc(folder)] = tempfile_loc(folder)
      Compass::Frameworks::ALL.each do |framework|
        Sass::Plugin.options[:template_location][framework.stylesheets_directory] = tempfile_loc(folder)
      end
      Sass::Plugin.update_stylesheets
      yield
    ensure
      @current_template_folder = nil
      Sass::Plugin.options[:template_location] = old_template_loc
    end
  rescue
    save_output(folder)    
    raise
  end
  
  def each_css_file(dir)
    Dir.glob("#{dir}/**/*.css").each do |css_file|
      yield css_file
    end
  end

  def save_output(dir)
    FileUtils.rm_rf(save_loc(dir))
    FileUtils.cp_r(tempfile_loc(dir), save_loc(dir))
  end

  def mkdir_clean(dir)
    begin
      FileUtils.mkdir dir
    rescue Errno::EEXIST
      FileUtils.rm_r dir
      FileUtils.mkdir dir
    end
  end

  def stylesheet_fixtures(folder)
    absolutize("fixtures/stylesheets/#{folder}")
  end

  def tempfile_loc(folder)
    "#{stylesheet_fixtures(folder)}/tmp"
  end
  
  def template_loc(folder)
    "#{stylesheet_fixtures(folder)}/sass"
  end
  
  def result_loc(folder)
    "#{stylesheet_fixtures(folder)}/css"
  end
  
  def save_loc(folder)
    "#{stylesheet_fixtures(folder)}/saved"
  end

end