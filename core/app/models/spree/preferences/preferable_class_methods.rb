module Spree::Preferences
  module PreferableClassMethods

    def preference(name, type, *args)
      options = args.extract_options!
      options.assert_valid_keys(:default)
      default = options[:default]

      # cache_key will be nil for new objects, then if we check if there
      # is a pending preference before going to default
      define_method preference_getter_method(name) do

        # perference_cache_key will only be nil/false for new records
        #
        if preference_cache_key(name)
          preference_store.get(preference_cache_key(name), default)
        else
          get_pending_preference(name) || default
        end
      end

      define_method preference_setter_method(name) do |value|
        value = convert_preference_value(value, type)
        if preference_cache_key(name)
          preference_store.set preference_cache_key(name), value
        else
          add_pending_preference(name, value)
        end
      end

      define_method preference_default_getter_method(name) do
        default
      end

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
