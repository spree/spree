module Spree::Preferences
  module PreferableClassMethods

    def preference(name, *args)
      options = args.extract_options!
      options.assert_valid_keys(:default)

      value_type = args.first
      default = options[:default]

      preferred_getter = "preferred_#{name}".to_sym
      preferred_setter = "preferred_#{name}=".to_sym
      prefers_getter = "prefers_#{name}?".to_sym
      prefers_setter = "prefers_#{name}=".to_sym
      default_getter = "preferred_#{name}_default".to_sym
      type_getter = "preferred_#{name}_type".to_sym

      define_method preferred_getter do
        if preference_store.exist? preference_cache_key(name)
          preference_store.get preference_cache_key(name)
        else
          send default_getter
        end
      end
      alias_method prefers_getter, preferred_getter

      define_method preferred_setter do |value|
        preference_store.set preference_cache_key(name), value
      end
      alias_method prefers_setter, preferred_setter

      define_method default_getter do
        default
      end

      define_method type_getter do
        value_type
      end

    end

    def remove_preference(name)
      preferred_getter = "preferred_#{name}".to_sym
      preferred_setter = "preferred_#{name}=".to_sym
      prefers_getter = "prefers_#{name}?".to_sym
      prefers_setter = "prefers_#{name}=".to_sym
      default_getter = "preferred_#{name}_default".to_sym
      type_getter = "preferred_#{name}_type".to_sym

      remove_method preferred_getter if method_defined? preferred_getter
      remove_method preferred_setter if method_defined? preferred_setter
      remove_method prefers_getter if method_defined? prefers_getter
      remove_method prefers_setter if method_defined? prefers_setter
      remove_method default_getter if method_defined? default_getter
      remove_method type_getter if method_defined? type_getter
    end

  end
end
