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
        preferences.fetch(name) do
          default.call
        end
      end

      define_method preference_setter_method(name) do |value|
        value = convert_preference_value(value, type)
        preferences[name] = value

        # If this is an activerecord object, we need to inform
        # ActiveRecord::Dirty that this value has changed, since this is an
        # in-place update to the preferences hash.
        preferences_will_change! if respond_to?(:preferences_will_change!)
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
