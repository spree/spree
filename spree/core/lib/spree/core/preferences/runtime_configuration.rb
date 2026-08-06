module Spree
  module Preferences
    class RuntimeConfiguration
      def initialize
        load_defaults
      end

      def reset
        load_defaults
      end

      def configure
        yield(self) if block_given?
      end

      def get(preference)
        warn_if_deprecated(preference)
        send(preference)
      end

      alias [] get

      def set(*args)
        options = args.extract_options!
        options.each do |name, value|
          warn_if_deprecated(name)
          send("#{name}=", value)
        end

        if args.size == 2
          warn_if_deprecated(args[0])
          send("#{args[0]}=", args[1])
        end
      end

      alias []= set

      private

      # Seeding defaults writes every preference, including the deprecated
      # ones, so it goes straight to the accessor — warning on boot would fire
      # for settings the application never touches.
      def load_defaults
        self.class.defaults.each { |key, value| send("#{key}=", value) }
      end

      def warn_if_deprecated(preference)
        message = self.class.deprecations[preference.to_sym]
        return if message.blank?

        Spree::Deprecation.warn(
          message.is_a?(String) ? "Spree::Config[:#{preference}] is deprecated. #{message}" : "Spree::Config[:#{preference}] is deprecated."
        )
      end

      class << self
        def preference(name, _type, default: nil, deprecated: false)
          defaults[name] = default
          deprecations[name] = deprecated
          attr_accessor name
        end

        def defaults
          @defaults ||= {}
        end

        def deprecations
          @deprecations ||= {}
        end
      end
    end
  end
end
