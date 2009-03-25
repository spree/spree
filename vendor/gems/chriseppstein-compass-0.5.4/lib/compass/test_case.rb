module Compass
  # Write your unit test like this if you want to make sure all your stylesheets compile.
  #
  # require 'compass/test_case'
  # class StylesheetsTest < Compass::TestCase
  #   def test_stylesheets
  #     my_sass_files.each do |sass_file|
  #       assert_compiles(sass_file) do |result|
  #         assert_not_blank result
  #       end
  #     end
  #   end
  #   protected
  #   def my_sass_files
  #     Dir.glob(File.expand_path(File.join(File.dirname(__FILE__), "../..", "app/stylesheets/**/[^_]*.sass")))
  #   end
  # end
  class TestCase < Test::Unit::TestCase
    def setup
      @last_compile = nil
    end

    def compile(stylesheet)
      input =  open(stylesheet)
      template = input.read()
      input.close()
      @last_compile = ::Sass::Engine.new(template,
        ::Sass::Plugin.engine_options(:style => :compact, :filename => stylesheet)).render
      yield @last_compile if block_given?
    end

    def assert_compiles(stylesheet, &block)
      compile(stylesheet, &block)
    end

  end
end
