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
      #
      # Env-backed settings are seeded with nil rather than their coded
      # default: the reader treats a set value as an explicit choice, so
      # writing the default here would shadow the environment. Their default
      # applies in the reader instead.
      def load_defaults
        self.class.defaults.each do |key, value|
          send("#{key}=", self.class.env_vars.key?(key) ? nil : value)
        end
      end

      def warn_if_deprecated(preference)
        message = self.class.deprecations[preference.to_sym]
        return if message.blank?

        Spree::Deprecation.warn(
          message.is_a?(String) ? "Spree::Config[:#{preference}] is deprecated. #{message}" : "Spree::Config[:#{preference}] is deprecated."
        )
      end

      class << self
        # Application-level settings (as opposed to store preferences, which
        # belong on Spree::Store). Passing +env+ lets an operator configure the
        # setting from the deployment environment instead of Ruby — the
        # supported path for anything infrastructural, since editing an
        # initializer means a code change and a deploy.
        #
        # Precedence is explicit value → env var → coded default, so a value
        # set in an initializer or at runtime always wins over the
        # environment; the env var only fills an unset preference.
        #
        # @param env [String, nil] environment variable backing this setting
        def preference(name, _type, default: nil, deprecated: false, env: nil)
          defaults[name] = default
          deprecations[name] = deprecated
          env_vars[name] = env if env

          attr_writer name

          if env
            # The ivar symbol is built once here — interpolating it inside
            # the reader would allocate a String on every read of an
            # env-backed setting, some of which sit on the request path.
            ivar = :"@#{name}"
            define_method(name) do
              value = instance_variable_get(ivar)
              return value unless value.nil?

              ENV[env].presence || default
            end
          else
            attr_reader name
          end
        end

        def defaults
          @defaults ||= {}
        end

        def deprecations
          @deprecations ||= {}
        end

        # @return [Hash{Symbol => String}] preferences backed by an env var
        def env_vars
          @env_vars ||= {}
        end
      end
    end
  end
end
