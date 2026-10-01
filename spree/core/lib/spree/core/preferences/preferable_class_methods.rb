module Spree::Preferences
  module PreferableClassMethods
    # Bumped by every declaration anywhere, so a class's cached view of its
    # preferences is rebuilt when an ancestor gains one after the class was
    # loaded — a decorator adding a secret to Spree::PaymentMethod, say.
    @declarations = 0

    class << self
      attr_accessor :declarations
    end

    # Every preference the class declares, inherited ones included, in
    # declaration order — so an admin form can present them the way their
    # author grouped them.
    #
    # @return [Hash{Symbol => Hash}] name => `{ type:, default:, deprecated:, internal:, choices:, nullable:, parse_on_set: }`
    def preference_definitions
      preference_declarations_cache[:definitions] ||= begin
        inherited = superclass.respond_to?(:preference_definitions) ? superclass.preference_definitions : {}
        inherited.merge(own_preference_definitions).freeze
      end
    end

    # Each declared preference's type, known from the declarations alone —
    # without building a record.
    #
    # @return [Hash{Symbol => Symbol}]
    def declared_preference_types
      preference_declarations_cache[:types] ||= preference_definitions.transform_values { |definition| definition[:type] }.freeze
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

    # Declares a typed preference with a `preferred_<name>` reader and writer
    # and a `prefers_<name>?` query. On a model, the value lives in the
    # `preferences` column (`secret_preferences` for a `:password` one) as a
    # Rails store accessor, which brings the change methods with it:
    # `preferred_<name>_changed?`, `_change`, `_was`,
    # `saved_change_to_preferred_<name>?` and `preferred_<name>_before_last_save`.
    def preference(name, type, *args)
      name = name.to_sym
      secret = type == :password
      if secret && !stores_secret_preferences?
        raise ArgumentError, "#{self.name} declares the secret preference `#{name}` but cannot encrypt it. " \
                             'Include Spree::SecretPreferences and add a `secret_preferences` text column to its table.'
      end

      options = args.extract_options!
      options.assert_valid_keys(:default, :deprecated, :in, :internal, :nullable, :parse_on_set)
      default = options[:default]
      default = -> { options[:default] } unless default.is_a?(Proc)
      own_preference_definitions[name] = {
        type: type,
        default: default,
        deprecated: options[:deprecated],
        # Whether the system writes the value rather than the operator — a
        # value a provider hands back, kept out of every admin form.
        internal: options[:internal],
        # The fixed set a value must come from; turns a text box into a picker.
        choices: options[:in],
        nullable: options[:nullable],
        parse_on_set: options[:parse_on_set]
      }
      PreferableClassMethods.declarations += 1

      store_accessor(secret ? :secret_preferences : :preferences, name, prefix: :preferred)

      # Overrides the store accessor's reader and writer, which treat a missing
      # key as nil; here a missing key means the declared default.
      define_method(:"preferred_#{name}") do
        restore_preference_value(stored_preference(name) { return preference_default(name) }, type)
      end

      define_method(:"preferred_#{name}=") do |value|
        write_preference(name, cast_preference(name, value))
      end

      define_method(:"prefers_#{name}?") do
        stored_preference(name) { raise KeyError, "key not found: #{name.inspect}" }.to_b
      end
    end

    private

    def own_preference_definitions
      @own_preference_definitions ||= {}
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
