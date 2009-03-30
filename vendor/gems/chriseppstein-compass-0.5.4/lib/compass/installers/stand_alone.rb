module Compass
  module Installers
    
    class StandAloneInstaller < Base

      def configure
        if File.exists?(config_file)
          Compass.configuration.parse(config_file)
        elsif File.exists?(old_config_file)
          Compass.configuration.parse(old_config_file)
        end
        super
      end

      def init
        directory targetize("")
        directory targetize(css_dir)
        directory targetize(sass_dir)
      end

      def prepare
        directory targetize(images_dir) if manifest.has_image?
        directory targetize(javascripts_dir) if manifest.has_javascript?
      end

      def default_css_dir
        Compass.configuration.css_dir || "stylesheets"
      end

      def default_sass_dir
        Compass.configuration.sass_dir ||"src"
      end

      def default_images_dir
        Compass.configuration.images_dir || "images"
      end

      def default_javascripts_dir
        Compass.configuration.javascripts_dir || "javascripts"
      end

      # Read the configuration file for this project
      def config_file
        @config_file ||= targetize('config.rb')
      end

      def old_config_file
        @old_config_file ||= targetize('src/config.rb')
      end

      def finalize(options = {})
        if options[:create]
          puts <<-NEXTSTEPS

Congratulations! Your compass project has been created.
You must recompile your sass stylesheets when they change.
This can be done in one of the following ways:
  1. From within your project directory run:
     compass
  2. From any directory run:
     compass -u path/to/project
  3. To monitor your project for changes and automatically recompile:
     compass --watch [path/to/project]

NEXTSTEPS
        end
        puts "To import your new stylesheets add the following lines of HTML (or equivalent) to your webpage:"
        puts stylesheet_links
      end

      def compilation_required?
        true
      end
    end
  end
end
