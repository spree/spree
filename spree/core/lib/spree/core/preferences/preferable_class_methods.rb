module Spree::Preferences
  module PreferableClassMethods
    # Bumped by every declaration anywhere, so a class's cached view of its
    # preferences is rebuilt when an ancestor gains one after the class was
    # loaded — a decorator adding a secret to Spree::PaymentMethod, say.
    @declarations = 0

    class << self
      attr_accessor :declarations
    end

    # Declaration order, so an admin form can present preferences the way
    # their author grouped them — credentials before the optional settings
    # that depend on them. `defined_preferences` reads Ruby's own `methods`,
    # whose order is an implementation detail, so it cannot answer this.
    def declared_preference_order
      declared_preference_types.keys
    end

    # Each declared preference's type, including those inherited, known from
    # the declarations alone — without building a record.
    #
    # @return [Hash{Symbol => Symbol}]
    def declared_preference_types
      preference_declarations_cache[:types] ||= begin
        inherited = superclass.respond_to?(:declared_preference_types) ? superclass.declared_preference_types : {}
        inherited.merge(own_preference_types).freeze
      end
    end

    # Names of the `:password` preferences, which a model including
    # {Spree::SecretPreferences} stores encrypted in `secret_preferences`.
    #
    # @return [Array<Symbol>]
    def secret_preference_names
      preference_declarations_cache[:secrets] ||= declared_preference_types.filter_map { |name, type| name if type == :password }.freeze
    end

    # Whether `:password` preferences are kept apart in an encrypted column.
    # {Spree::SecretPreferences} turns this on.
    def stores_secret_preferences?
      false
    end

    def preference(name, type, *args)
      if type == :password && self < ActiveRecord::Base && !stores_secret_preferences?
        raise ArgumentError, "#{self.name} declares the secret preference `#{name}` but cannot encrypt it. " \
                             'Include Spree::SecretPreferences and add a `secret_preferences` text column to its table.'
      end

      own_preference_types[name.to_sym] = type
      PreferableClassMethods.declarations += 1
      options = args.extract_options!
      options.assert_valid_keys(:default, :deprecated, :in, :internal, :nullable, :parse_on_set)
      default = options[:default]
      default = -> { options[:default] } unless default.is_a?(Proc)
      deprecated = options[:deprecated]
      internal = options[:internal]
      # The fixed set a value must come from. Turns a text box into a picker
      # in every admin form, and is what the inclusion validation would have
      # told the operator only after a failed save.
      choices = options[:in]
      nullable = options[:nullable]
      parse_on_set = options[:parse_on_set]

      define_method preference_getter_method(name) do
        value = stored_preference(name) { return default.call }
        # JSON keeps a decimal as its exact string; the declared type restores it.
        type == :decimal && value.is_a?(String) ? value.to_d : value
      end

      define_method preference_setter_method(name) do |value|
        if parse_on_set.is_a?(Proc)
          # Procs that accept more than one arg opt into receiving the
          # owning record so they can scope (e.g. `normalize_id_preference`
          # rejecting cross-store IDs). `arity.abs > 1` covers both the
          # `(value, owner)` and `(value, owner = nil)` shapes.
          value = parse_on_set.arity.abs > 1 ? parse_on_set.call(value, self) : parse_on_set.call(value)
        end
        value = convert_preference_value(value, type, nullable: nullable)
        # A decimal is kept in the exact-string form JSON stores, so a record
        # read back from the database and one just written compare equal and
        # setting the same value is not a change. The reader restores it.
        preference_storage(name)[name] = type == :decimal ? value.as_json : value

        Spree::Deprecation.warn("`#{name}` is deprecated. #{deprecated}") if deprecated

        # If this is an activerecord object, we need to inform
        # ActiveRecord::Dirty that this value has changed, since this is an
        # in-place update to the preferences hash.
        if secret_preference?(name)
          # A copy assigned as part of a whole hash would otherwise outlive the
          # value written here and be moved over it on save.
          preferences_will_change! if preferences&.delete(name)
          secret_preferences_will_change!
        elsif respond_to?(:preferences_will_change!)
          preferences_will_change!
        end
      end

      define_method preference_default_getter_method(name), &default

      define_method preference_type_getter_method(name) do
        type
      end

      define_method preference_deprecated_getter_method(name) do
        deprecated
      end

      # Whether this preference is the system's to write rather than the
      # operator's to supply — a value a provider hands back to us, not one
      # anybody could know in advance.
      define_method preference_internal_getter_method(name) do
        internal
      end

      define_method preference_choices_getter_method(name) do
        choices.respond_to?(:call) ? choices.call : choices
      end

      define_method prefers_query_method(name) do
        stored_preference(name) { raise KeyError, "key not found: #{name.inspect}" }.to_b
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

    def preference_internal_getter_method(name)
      "preferred_#{name}_internal".to_sym
    end

    def preference_choices_getter_method(name)
      "preferred_#{name}_choices".to_sym
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

    private

    def own_preference_types
      @own_preference_types ||= {}
    end

    def preference_declarations_cache
      generation = PreferableClassMethods.declarations
      unless @preference_declarations_generation == generation
        @preference_declarations_generation = generation
        @preference_declarations_cache = {}
      end
      @preference_declarations_cache
    end
  end
end
