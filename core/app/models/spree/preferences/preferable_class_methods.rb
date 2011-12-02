module Spree::Preferences
  module PreferableClassMethods

    def preference(name, type, *args)
      options = args.extract_options!
      options.assert_valid_keys(:default)

      value_type = args.first
      default = options[:default]

      define_method preference_getter_method(name) do
        if preference_store.exist? preference_cache_key(name)
          preference_store.get preference_cache_key(name)
        else
          send self.class.preference_default_getter_method(name)
        end
      end
      alias_method prefers_getter_method(name), preference_getter_method(name)

      define_method preference_setter_method(name) do |value|
        # Boolean attributes can come back from forms as '0' or '1'
        # Convert them to their correct values here
        if type == :boolean && !value.is_a?(TrueClass) && !value.is_a?(FalseClass)
          value = value.to_i == 1
        end
        preference_store.set preference_cache_key(name), value
      end
      alias_method prefers_setter_method(name), preference_setter_method(name)

      define_method preference_default_getter_method(name) do
        default
      end

      define_method preference_type_getter_method(name) do
        value_type
      end

    end

    def remove_preference(name)
      remove_method preference_getter_method(name) if method_defined? preference_getter_method(name)
      remove_method preference_setter_method(name) if method_defined? preference_setter_method(name)
      remove_method prefers_getter_method(name) if method_defined? prefers_getter_method(name)
      remove_method prefers_setter_method(name) if method_defined? prefers_setter_method(name)
      remove_method preference_default_getter_method(name) if method_defined? preference_default_getter_method(name)
      remove_method preference_type_getter_method(name) if method_defined? preference_type_getter_method(name)
    end

    def preference_getter_method(name)
      "preferred_#{name}".to_sym
    end

    def preference_setter_method(name)
       "preferred_#{name}=".to_sym
    end

    def prefers_getter_method(name)
      "prefers_#{name}?".to_sym
    end

    def prefers_setter_method(name)
       "prefers_#{name}=".to_sym
    end

    def preference_default_getter_method(name)
      "preferred_#{name}_default".to_sym
    end

    def preference_type_getter_method(name)
      "preferred_#{name}_type".to_sym
    end

  end
end
