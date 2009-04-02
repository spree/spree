module Compass
  module Installers
    
    class RailsInstaller < Base

      def configure
        configuration_file = targetize('config/initializers/compass.rb')
        if File.exists?(configuration_file)
          open(configuration_file) do |config|
            eval(config.read, nil, configuration_file)
          end
        end
        Compass.configuration.set_maybe(options)
      end

      def init
        set_sass_dir unless sass_dir
        set_css_dir unless css_dir
        directory targetize(css_dir)
        directory targetize(sass_dir)
        write_file targetize('config/initializers/compass.rb'), initializer_contents
      end

      def prepare
      end

      def finalize(options = {})
        if options[:create]
          puts <<-NEXTSTEPS

Congratulations! Your rails project has been configured to use Compass.
Sass will automatically compile your stylesheets during the next
page request and keep them up to date when they change.
Make sure you restart your server!

Next add these lines to the head of your layouts:

NEXTSTEPS
        end
        puts stylesheet_links
        puts "\n(You are using haml, aren't you?)"
      end

      def sass_dir
        Compass.configuration.sass_dir
      end

      def css_dir
        Compass.configuration.css_dir
      end

      def images_dir
        separate "public/images"
      end

      def javascripts_dir
        separate "public/javascripts"
      end

      def set_sass_dir
        recommended_location = separate('app/stylesheets')
        default_location = separate('public/stylesheets/sass')
        print %Q{Compass recommends that you keep your stylesheets in #{recommended_location}
instead of the Sass default location of #{default_location}.
Is this OK? (Y/n) }
        answer = gets.downcase[0]
        Compass.configuration.sass_dir = answer == ?n ? default_location : recommended_location
      end

      def set_css_dir
        recommended_location = separate("public/stylesheets/compiled")
        default_location = separate("public/stylesheets")
        puts
        print %Q{Compass recommends that you keep your compiled css in #{recommended_location}/
instead the Sass default of #{default_location}/.
However, if you're exclusively using Sass, then #{default_location}/ is recommended.
Emit compiled stylesheets to #{recommended_location}/? (Y/n) }
        answer = gets.downcase[0]
        Compass.configuration.css_dir = answer == ?n ? default_location : recommended_location
      end

      def initializer_contents
        %Q{require 'compass'
# If you have any compass plugins, require them here.
Compass.configuration do |config|
  config.project_path = RAILS_ROOT
  config.sass_dir = "#{sass_dir}"
  config.css_dir = "#{css_dir}"
end
Compass.configure_sass_plugin!
}
      end

      def stylesheet_prefix
        if css_dir.length >= 19
          "#{css_dir[19..-1]}/"
        else
          nil
        end
      end

      def stylesheet_links
        html = "%head\n"
        manifest.each_stylesheet do |stylesheet|
          ss_line = "  = stylesheet_link_tag '#{stylesheet_prefix}#{stylesheet.to.sub(/\.sass$/,'.css')}'"
          if stylesheet.options[:media]
            ss_line += ", :media => '#{stylesheet.options[:media]}'"
          end
          if stylesheet.options[:ie]
            ss_line = "  /[if IE]\n  " + ss_line
          end
          html << ss_line + "\n"
        end
        html
      end
    end
  end
end
