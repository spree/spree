module Spree
  module Preferences
    class RuntimeConfiguration
      def initialize
        self.class.defaults.each do |key, value|
          self[key] = value
        end
      end

      def configure
        yield(self) if block_given?
      end

      def get(preference)
        send(preference)
      end

      alias [] get

      def set(preference, value)
        send("#{preference}=", value)
      end

      alias []= set

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
