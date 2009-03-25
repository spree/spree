require 'singleton'

module Compass
  class Configuration
    include Singleton

    ATTRIBUTES = [
      :project_path,
      :css_dir,
      :sass_dir,
      :images_dir,
      :javascripts_dir,
      :output_style,
      :environment
    ]

    attr_accessor *ATTRIBUTES

    attr_accessor :required_libraries

    def initialize
      self.required_libraries = []
    end

    # parses a manifest file which is a ruby script
    # evaluated in a Manifest instance context
    def parse(config_file)
      open(config_file) do |f|
        parse_string(f.read, config_file)
      end
    end

    def parse_string(contents, filename)
      eval(contents, binding, filename)
      ATTRIBUTES.each do |prop|
        value = eval(prop.to_s, binding) rescue nil
        self.send("#{prop}=", value) if value
      end
    end

    def set_all(options)
      ATTRIBUTES.each do |a|
        self.send("#{a}=", options[a]) if options.has_key?(a)
      end
    end

    def set_maybe(options)
      ATTRIBUTES.each do |a|
        self.send("#{a}=", options[a]) if options[a]
      end
    end

    def default_all(options)
      ATTRIBUTES.each do |a|
        self.send("#{a}=", options[a]) unless self.send(a)
      end
    end

    def set_defaults!
      default_all(ATTRIBUTES.inject({}){|m, a| m[a] = default_for(a); m})
    end

    def default_for(attribute)
      method = "default_#{attribute}".to_sym
      self.send(method) if respond_to?(method)
    end

    def default_sass_dir
      "src"
    end

    def default_css_dir
      "stylesheets"
    end

    def default_output_style
      if environment == :development
        :expanded
      else
        :compact
      end
    end

    def serialize
      contents = ""
      required_libraries.each do |lib|
        contents << %Q{require '#{lib}'\n}
      end
      contents << "# Require any additional compass plugins here.\n"
      contents << "\n" if required_libraries.any?
      ATTRIBUTES.each do |prop|
        value = send(prop)
        unless value.nil?
          contents << %Q(#{prop} = #{value.inspect}\n)
        end
      end
      contents
    end

    def to_sass_plugin_options
      if project_path && sass_dir && css_dir
        proj_sass_path = File.join(project_path, sass_dir)
        proj_css_path = File.join(project_path, css_dir)
        locations = {proj_sass_path => proj_css_path}
      else
        locations = {}
      end
      Compass::Frameworks::ALL.each do |framework|
        locations[framework.stylesheets_directory] = proj_css_path || css_dir || "."
      end
      plugin_opts = {:template_location => locations}
      plugin_opts[:style] = output_style if output_style
      plugin_opts
    end

    def to_sass_engine_options
      engine_opts = {:load_paths => sass_load_paths}
      engine_opts[:style] = output_style if output_style
      engine_opts
    end

    def sass_load_paths
      load_paths = []
      if project_path && sass_dir
        load_paths << File.join(project_path, sass_dir)
      end
      Compass::Frameworks::ALL.each do |framework|
        load_paths << framework.stylesheets_directory
      end
      load_paths
    end

    # Support for testing.
    def reset!
      ATTRIBUTES.each do |attr|
        send("#{attr}=", nil)
      end
      self.required_libraries = []
    end

    def require(lib)
      required_libraries << lib
      super
    end

  end

  module ConfigHelpers
    def configuration
      if block_given?
        yield Configuration.instance
      end
      Configuration.instance
    end

    def sass_plugin_configuration
      configuration.to_sass_plugin_options
    end

    def configure_sass_plugin!
      Sass::Plugin.options.merge!(sass_plugin_configuration)
    end

    def sass_engine_options
      configuration.to_sass_engine_options
    end
  end

  extend ConfigHelpers

end
