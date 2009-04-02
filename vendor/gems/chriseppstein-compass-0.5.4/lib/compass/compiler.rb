module Compass
  class Compiler

    include Actions

    attr_accessor :working_path, :from, :to, :options

    def initialize(working_path, from, to, options)
      self.working_path = working_path
      self.from, self.to = from, to
      self.logger = options.delete(:logger)
      self.options = options
    end

    def sass_files
      @sass_files || Dir.glob(separate("#{from}/**/[^_]*.sass"))
    end

    def stylesheet_name(sass_file)
      sass_file[("#{from}/".length)..-6]
    end

    def css_files
      @css_files || sass_files.map{|sass_file| "#{to}/#{stylesheet_name(sass_file)}.css"}
    end

    def target_directories
      css_files.map{|css_file| File.dirname(css_file)}.uniq.sort.sort_by{|d| d.length }
    end

    def run
      target_directories.each do |dir|
        directory dir
      end
      sass_files.zip(css_files).each do |sass_filename, css_filename|
        compile sass_filename, css_filename, options
      end
    end
  end
end