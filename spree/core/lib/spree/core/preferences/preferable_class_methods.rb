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

    # The value types a list item, a hash value or an object property may
    # declare, and the formats a string may carry. They are what
    # {Spree::PreferenceSchema::JsonSchema} compiles to JSON Schema.
    ITEM_TYPES = %i[string integer decimal money boolean id object].freeze
    FORMATS = %i[currency iso_country timezone locale url color].freeze

    # Declares a typed preference with a `preferred_<name>` reader and writer
    # and a `prefers_<name>?` query. On a model, the value lives in the
    # `preferences` column (`secret_preferences` for a `:password` one) as a
    # Rails store accessor, which brings the change methods with it:
    # `preferred_<name>_changed?`, `_change`, `_was`,
    # `saved_change_to_preferred_<name>?` and `preferred_<name>_before_last_save`.
    #
    # The declaration is the preference's contract on the wire, so it states
    # the full type:
    #
    #   preference :amount_min,    :decimal, money: true
    #   preference :channel_ids,   :array, of: :id, model: 'Spree::Channel', scope: ->(rule) { rule.store.channels }
    #   preference :country_codes, :array, of: :string, format: :iso_country
    #   preference :match_policy,  :string, choices: %w[any all none]
    #   preference :amounts,       :hash, keys: :currency, values: :money
    #   preference :tiers,         :array, of: :object, properties: { threshold: :money, value: :decimal }
    #
    # @param name [Symbol]
    # @param type [Symbol] `:string`, `:text`, `:boolean`, `:integer`, `:decimal`,
    #   `:array`, `:hash`, `:password`, `:date` or `:datetime`
    # @option options [Symbol] :of the type of each item of an `:array`
    # @option options [Symbol] :keys the type of a `:hash`'s keys (`:string` or `:currency`)
    # @option options [Symbol] :values the type of a `:hash`'s values
    # @option options [Hash{Symbol => Symbol}] :properties the fields of each `of: :object` item
    # @option options [Boolean] :money a `:decimal` that is an amount of money
    # @option options [Symbol] :format a string's domain format (see {FORMATS})
    # @option options [String, Proc] :model the record class an `of: :id` list points at
    # @option options [Proc] :scope `->(owner) { relation }` the ids must be found in
    # @option options [Array, Proc] :choices the fixed set a value must come from
    def preference(name, type, *args)
      name = name.to_sym
      secret = type == :password
      if secret && !include?(Spree::SecretPreferences)
        raise ArgumentError, "#{self.name} declares the secret preference `#{name}` but cannot encrypt it. " \
                             'Include Spree::SecretPreferences and add a `secret_preferences` text column to its table.'
      end

      options = args.extract_options!
      options.assert_valid_keys(:default, :deprecated, :in, :choices, :internal, :nullable, :parse_on_set,
                                :of, :keys, :values, :properties, :money, :format, :model, :scope)
      if options.key?(:in)
        Spree::Deprecation.warn("`preference :#{name}, in:` is deprecated. Use `choices:` instead.")
        options[:choices] ||= options.delete(:in)
      end
      check_preference_declaration(name, type, options)

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
        choices: options[:choices],
        nullable: options[:nullable],
        parse_on_set: options[:parse_on_set],
        of: options[:of],
        keys: options[:keys],
        values: options[:values],
        properties: options[:properties],
        money: options[:money],
        format: options[:format],
        model: options[:model],
        scope: options[:scope]
      }
      PreferableClassMethods.declarations += 1

      store_accessor(secret ? :secret_preferences : :preferences, name, prefix: :preferred)

      # Overrides the store accessor's reader and writer, which treat a missing
      # key as nil; here a missing key means the declared default.
      define_method(:"preferred_#{name}") do
        Spree::Preferences::Preferable.restore_value(stored_preference(name) { stored_default(name) }, type)
      end

      define_method(:"preferred_#{name}=") do |value|
        write_preference(name, cast_preference(name, value))
      end

      define_method(:"prefers_#{name}?") do
        stored_preference(name) { raise KeyError, "key not found: #{name.inspect}" }.to_b
      end
    end

    # Gives each named preference a plain reader and writer, so the API reads
    # and writes `guest_checkout` rather than the DSL's `preferred_guest_checkout`.
    # Grants no write access: each API controller still lists what it permits.
    #
    #   exposes_preferences :guest_checkout, :timezone
    #
    # @param names [Array<Symbol>]
    # @return [void]
    def exposes_preferences(*names)
      names.each do |name|
        name = name.to_sym
        raise ArgumentError, "#{self.name} has no preference `#{name}` to expose" unless preference_definitions.key?(name)
        raise ArgumentError, "#{self.name} cannot expose the preference `#{name}`: a method of that name exists" if method_defined?(name)

        define_method(name) { public_send(:"preferred_#{name}") }
        define_method(:"#{name}=") { |value| public_send(:"preferred_#{name}=", value) }
      end
    end

    private

    # A declaration is the preference's contract on the wire. One Spree ships
    # is always complete (a spec enforces it); an incomplete one from an
    # extension still works in 6.0, with a schema that accepts any value.
    def check_preference_declaration(name, type, options)
      if options[:of] && type != :array
        raise ArgumentError, "`of:` applies to an :array preference, not `#{name}` (#{type})"
      end
      if (options[:keys] || options[:values]) && type != :hash
        raise ArgumentError, "`keys:` and `values:` apply to a :hash preference, not `#{name}` (#{type})"
      end
      if options[:money] && type != :decimal
        raise ArgumentError, "`money:` applies to a :decimal preference, not `#{name}` (#{type})"
      end
      [options[:of], options[:values], *options[:properties]&.values].compact.each do |item_type|
        raise ArgumentError, "Unknown item type `#{item_type}` on preference `#{name}`" unless ITEM_TYPES.include?(item_type)
      end
      raise ArgumentError, "Unknown format `#{options[:format]}` on preference `#{name}`" if options[:format] && FORMATS.exclude?(options[:format])
      raise ArgumentError, "`of: :id` needs `model:` on preference `#{name}`" if options[:of] == :id && options[:model].blank?
      raise ArgumentError, "`of: :object` needs `properties:` on preference `#{name}`" if options[:of] == :object && options[:properties].blank?

      missing = case type
                when :any then 'a type other than :any'
                when :array then '`of:`' unless options[:of]
                when :hash then '`keys:` and `values:`' unless options[:keys] && options[:values]
                end
      return unless missing

      Spree::Deprecation.warn(
        "#{self.name} preference `#{name}` (#{type}) needs #{missing}; until it has one, its schema accepts any value. " \
        'Spree 6.1 will raise for an incomplete declaration.'
      )
    end

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
