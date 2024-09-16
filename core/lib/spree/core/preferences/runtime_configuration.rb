module Spree
  module Preferences
    class RuntimeConfiguration
      def initialize
        self.class.defaults.each do |key, value|
          self[key] = value
        end
      end

      def reset
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

      def set(*args)
        options = args.extract_options!
        options.each do |name, value|
          send("#{name}=", value)
        end

        send("#{args[0]}=", args[1]) if args.size == 2
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
