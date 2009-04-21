unless defined?(Sass::MERB_LOADED)
  Sass::MERB_LOADED = true

  version = Merb::VERSION.split('.').map { |n| n.to_i }
  if version[0] <= 0 && version[1] < 5
    root = MERB_ROOT
    env  = MERB_ENV
  else
    root = Merb.root.to_s
    env  = Merb.environment
  end

  Sass::Plugin.options.merge!(:template_location  => root + '/public/stylesheets/sass',
                              :css_location       => root + '/public/stylesheets',
                              :always_check       => env != "production",
                              :full_exception     => env != "production")
  config = Merb::Plugins.config[:sass] || Merb::Plugins.config["sass"] || {}

  if defined? config.symbolize_keys!
    config.symbolize_keys!
  end

  Sass::Plugin.options.merge!(config)

  if version[0] > 0 || version[1] >= 9

    class Merb::Rack::Application # :nodoc:
      def call_with_sass(env)
        if !Sass::Plugin.checked_for_updates ||
            Sass::Plugin.options[:always_update] || Sass::Plugin.options[:always_check]
          Sass::Plugin.update_stylesheets
        end

        call_without_sass(env)
      end
      alias_method :call_without_sass, :call
      alias_method :call, :call_with_sass
    end

  else

    class MerbHandler # :nodoc:
      def process_with_sass(request, response)
        if !Sass::Plugin.checked_for_updates ||
            Sass::Plugin.options[:always_update] || Sass::Plugin.options[:always_check]
          Sass::Plugin.update_stylesheets
        end

        process_without_sass(request, response)
      end
      alias_method :process_without_sass, :process
      alias_method :process, :process_with_sass
    end

  end
end
