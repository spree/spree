module Spree::Preferences
  module PreferableClassMethods

    def preference(name, type, *args)
      options = args.extract_options!
      options.assert_valid_keys(:default, :description)
      default = options[:default]
      description = options[:description] || name

      # cache_key will be nil for new objects, then if we check if there
      # is a pending preference before going to default
      define_method preference_getter_method(name) do
        if preference_cache_key(name) && preference_store.exist?(preference_cache_key(name))
          preference_store.get preference_cache_key(name)
        else
          if get_pending_preference(name)
            get_pending_preference(name)
          elsif Spree::Preference.table_exists? && preference = Spree::Preference.find_by_key(preference_cache_key(name))
            preference.value
          else
            send self.class.preference_default_getter_method(name)
          end
        end
      end
      alias_method prefers_getter_method(name), preference_getter_method(name)

      define_method preference_setter_method(name) do |value|
        value = convert_preference_value(value, type)
        if preference_cache_key(name)
          preference_store.set preference_cache_key(name), value, type
        else
          add_pending_preference(name, value)
        end
      end
      alias_method prefers_setter_method(name), preference_setter_method(name)

      define_method preference_default_getter_method(name) do
        default
      end

      define_method preference_type_getter_method(name) do
        type
      end

      define_method preference_description_getter_method(name) do
        description
      end
    end

    def remove_preference(name)
      remove_method preference_getter_method(name) if method_defined? preference_getter_method(name)
      remove_method preference_setter_method(name) if method_defined? preference_setter_method(name)
      remove_method prefers_getter_method(name) if method_defined? prefers_getter_method(name)
      remove_method prefers_setter_method(name) if method_defined? prefers_setter_method(name)
      remove_method preference_default_getter_method(name) if method_defined? preference_default_getter_method(name)
      remove_method preference_type_getter_method(name) if method_defined? preference_type_getter_method(name)
      remove_method preference_description_getter_method(name) if method_defined? preference_description_getter_method(name)
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

    def preference_description_getter_method(name)
      "preferred_#{name}_description".to_sym
    end

  end
end
