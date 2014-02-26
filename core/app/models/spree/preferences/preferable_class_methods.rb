module Spree::Preferences
  module PreferableClassMethods

    def preference(name, type, *args)
      options = args.extract_options!
      options.assert_valid_keys(:default)
      default = options[:default]
      default = ->{ options[:default] } unless default.is_a?(Proc)

      # cache_key will be nil for new objects, then if we check if there
      # is a pending preference before going to default
      define_method preference_getter_method(name) do
        preference_store.fetch(name) do
          default.call
        end
      end

      define_method preference_setter_method(name) do |value|
        value = convert_preference_value(value, type)
        preference_store[name] = value
      end

      define_method preference_default_getter_method(name), &default

      define_method preference_type_getter_method(name) do
        type
      end
    end

    def preference_getter_method(name)
      "preferred_#{name}".to_sym
    end

    def preference_setter_method(name)
       "preferred_#{name}=".to_sym
    end

    def preference_default_getter_method(name)
      "preferred_#{name}_default".to_sym
    end

    def preference_type_getter_method(name)
      "preferred_#{name}_type".to_sym
    end
  end
end
