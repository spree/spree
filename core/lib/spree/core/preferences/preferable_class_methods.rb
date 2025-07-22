module Spree::Preferences
  module PreferableClassMethods
    def preference(name, type, *args)
      options = args.extract_options!
      options.assert_valid_keys(:default, :deprecated, :nullable, :parse_on_set)
      default = options[:default]
      default = -> { options[:default] } unless default.is_a?(Proc)
      deprecated = options[:deprecated]
      nullable = options[:nullable]
      parse_on_set = options[:parse_on_set]

      # cache_key will be nil for new objects, then if we check if there
      # is a pending preference before going to default
      define_method preference_getter_method(name) do
        preferences.fetch(name) do
          default.call
        end
      end

      define_method preference_setter_method(name) do |value|
        value = parse_on_set.call(value) if parse_on_set.is_a?(Proc)
        value = convert_preference_value(value, type, nullable: nullable)
        preferences[name] = value

        Spree::Deprecation.warn("`#{name}` is deprecated. #{deprecated}") if deprecated

        # If this is an activerecord object, we need to inform
        # ActiveRecord::Dirty that this value has changed, since this is an
        # in-place update to the preferences hash.
        preferences_will_change! if respond_to?(:preferences_will_change!)
      end

      define_method preference_default_getter_method(name), &default

      define_method preference_type_getter_method(name) do
        type
      end

      define_method preference_deprecated_getter_method(name) do
        deprecated
      end

      define_method prefers_query_method(name) do
        preferences.fetch(name).to_b
      end

      define_method preference_change_method(name) do
        preference_change(name, changes) if respond_to?(:changes)
      end

      define_method preference_was_method(name) do
        return unless respond_to?(:changes)

        preference_change(name, changes)&.first || get_preference(name)
      end

      define_method preference_changed_method(name) do
        respond_to?(:changes) && preference_change(name, changes).present?
      end

      define_method preference_previous_change_method(name) do
        preference_change(name, previous_changes) if respond_to?(:previous_changes)
      end

      define_method preference_previous_was_method(name) do
        return unless respond_to?(:previous_changes)

        preference_change(name, previous_changes)&.first
      end

      define_method preference_previous_changed_method(name) do
        respond_to?(:previous_changes) && preference_change(name, previous_changes).present?
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

    def preference_deprecated_getter_method(name)
      "preferred_#{name}_deprecated".to_sym
    end

    def preference_type_getter_method(name)
      "preferred_#{name}_type".to_sym
    end

    def prefers_query_method(name)
      "prefers_#{name}?".to_sym
    end

    def preference_change_method(name)
      "preferred_#{name}_change".to_sym
    end

    def preference_was_method(name)
      "preferred_#{name}_was".to_sym
    end

    def preference_changed_method(name)
      "preferred_#{name}_changed?".to_sym
    end

    def preference_previous_change_method(name)
      "preferred_#{name}_previous_change".to_sym
    end

    def preference_previous_was_method(name)
      "preferred_#{name}_previously_was".to_sym
    end

    def preference_previous_changed_method(name)
      "preferred_#{name}_previously_changed?".to_sym
    end
  end
end
