unless defined?(Sass::RAILS_LOADED)
  Sass::RAILS_LOADED = true

  Sass::Plugin.options.merge!(:template_location  => RAILS_ROOT + '/public/stylesheets/sass',
                              :css_location       => RAILS_ROOT + '/public/stylesheets',
                              :always_check       => RAILS_ENV != "production",
                              :full_exception     => RAILS_ENV != "production")

  # :stopdoc:
  module ActionController
    class Base
      alias_method :sass_old_process, :process
      def process(*args)
        if !Sass::Plugin.checked_for_updates ||
            Sass::Plugin.options[:always_update] || Sass::Plugin.options[:always_check]
          Sass::Plugin.update_stylesheets
        end

        sass_old_process(*args)
      end
    end
  end
  # :startdoc:
end
