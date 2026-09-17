module Spree
  module Preferences
    # Raised when an environment variable backing a preference holds a value
    # that does not parse as the declared type.
    class InvalidEnvironmentValue < StandardError
      def initialize(variable, value, type, expected = nil)
        article = type == :integer ? 'an' : 'a'
        expected ||= "#{article} #{type}"
        super("#{variable}=#{value.inspect} is not valid for #{article} #{type} setting. Expected #{expected}.")
      end
    end

    class RuntimeConfiguration
      # Deliberately not ActiveModel::Type::Boolean: it casts "no", "Off" and
      # every unrecognised string — a typo included — to true.
      BOOLEAN_TRUE = %w[true 1 yes on].freeze
      BOOLEAN_FALSE = %w[false 0 no off].freeze

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
        # @param type [Symbol] declared type, used to coerce the env var
        # @param env [String, nil] environment variable backing this setting
        def preference(name, type, default: nil, deprecated: false, env: nil)
          defaults[name] = default
          deprecations[name] = deprecated
          types[name] = type
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

              raw = ENV[env]
              return default if raw.nil? || raw.empty?

              # Memoized into the ivar so coercion runs once per process, not
              # once per read — these sit on the request path.
              instance_variable_set(ivar, self.class.coerce_env(env, raw, type))
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

        # @return [Hash{Symbol => Symbol}] declared type per preference
        def types
          @types ||= {}
        end

        # @return [Hash{Symbol => String}] preferences backed by an env var
        def env_vars
          @env_vars ||= {}
        end

        # Reads every env-backed preference so a malformed value fails at boot
        # rather than on the first request that happens to read it. Reading
        # also memoizes the coerced value, so this doubles as a warm-up.
        #
        # @param instance [RuntimeConfiguration] configuration to validate
        # @raise [Spree::Preferences::InvalidEnvironmentValue]
        # @return [void]
        def validate_env!(instance)
          env_vars.each_key { |name| instance.public_send(name) }
          nil
        end

        # Env vars arrive as strings, so an uncoerced `SPREE_X=false` would be
        # the truthy String "false". Coercion is strict: a value that does not
        # parse raises rather than falling back to the default, since a typo'd
        # setting silently reverting is worse than a failed boot.
        #
        # @param variable [String] name of the environment variable
        # @param value [String] raw value read from the environment
        # @param type [Symbol] declared preference type
        # @return [Object] the coerced value
        def coerce_env(variable, value, type)
          case type
          when :boolean then coerce_env_boolean(variable, value)
          when :integer then coerce_env_number(variable, value, type) { Integer(value, 10) }
          when :decimal then coerce_env_number(variable, value, type) { BigDecimal(value) }
          when :array then value.split(',').map(&:strip).reject(&:empty?)
          else value
          end
        end

        private

        def coerce_env_boolean(variable, value)
          normalized = value.strip.downcase
          return true if BOOLEAN_TRUE.include?(normalized)
          return false if BOOLEAN_FALSE.include?(normalized)

          raise InvalidEnvironmentValue.new(variable, value, :boolean, "#{BOOLEAN_TRUE.join(', ')}, #{BOOLEAN_FALSE.join(', ')}")
        end

        def coerce_env_number(variable, value, type)
          yield
        rescue ArgumentError, TypeError
          raise InvalidEnvironmentValue.new(variable, value, type)
        end
      end
    end
  end
end
