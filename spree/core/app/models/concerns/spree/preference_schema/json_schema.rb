module Spree
  module PreferenceSchema
    # Compiles a class's preference declarations into the JSON Schema of its
    # `preferences` object — the contract the OpenAPI components, the SDK
    # types, the `/…/types` endpoints and write validation all read, so none
    # of them is written by hand.
    module JsonSchema
      DECIMAL_PATTERN = '^-?\d+(\.\d+)?$'.freeze

      # Domain formats, with the pattern that makes each one checkable by any
      # validator, not only those that know the format's name.
      FORMATS = {
        currency: { format: 'currency', pattern: '^[A-Z]{3}$' },
        iso_country: { format: 'iso-country', pattern: '^[A-Z]{2}$' },
        timezone: { format: 'timezone' },
        locale: { format: 'locale' },
        url: { format: 'uri' },
        color: { format: 'color', pattern: '^#[0-9A-Fa-f]{6}$' }
      }.freeze

      # @param klass [Class] a class including {Spree::PreferenceSchema}
      # @return [Hash] a JSON Schema object (string keys), or nil when the
      #   declarations could not be read yet (no database connection)
      def self.for(klass)
        fields = klass.preference_schema
        return nil if fields.empty? && !klass.preference_schema_computed?

        definitions = klass.preference_definitions
        properties = fields.to_h { |field| [field[:key].to_s, property(field, definitions.fetch(field[:key]))] }

        { 'type' => 'object', 'properties' => properties, 'additionalProperties' => false }
      end

      def self.property(field, definition)
        schema = value_schema(definition)
        choices = field[:choices]
        schema['enum'] = choices.map { |choice| choice.is_a?(Symbol) ? choice.to_s : choice } if choices.present?
        default = wire_default(field[:default], definition)

        # A value nothing has set reads back as null, so a preference without
        # a default is nullable on the wire whatever its declared type — and so
        # is a secret, whose default is never sent.
        if (definition[:nullable] || default.nil? || definition[:type] == :password) && schema['type']
          schema['type'] = [schema['type'], 'null']
          schema['enum'] += [nil] if schema['enum']
        end
        # A secret's default would leak alongside the masked value.
        schema['default'] = default unless default.nil? || definition[:type] == :password
        schema
      end

      def self.value_schema(definition)
        case definition[:type]
        when :string then string_schema(definition[:format])
        when :text then { 'type' => 'string', 'x-spree-widget' => 'textarea' }
        when :boolean then { 'type' => 'boolean' }
        when :integer then { 'type' => 'integer' }
        when :decimal then item_schema(definition[:money] ? :money : :decimal, definition)
        when :password then { 'type' => 'string', 'x-spree-secret' => true }
        when :date then { 'type' => 'string', 'format' => 'date' }
        when :datetime then { 'type' => 'string', 'format' => 'date-time' }
        when :array
          schema = { 'type' => 'array' }
          schema['items'] = item_schema(definition[:of], definition) if definition[:of]
          schema
        when :hash
          schema = { 'type' => 'object' }
          if definition[:keys] && definition[:values]
            schema['propertyNames'] = definition[:keys] == :currency ? string_schema(:currency) : { 'type' => 'string' }
            schema['additionalProperties'] = item_schema(definition[:values], definition)
          end
          schema
        else
          {}
        end
      end

      def self.item_schema(item_type, definition)
        case item_type
        when :string then string_schema(definition[:format])
        when :integer then { 'type' => 'integer' }
        when :boolean then { 'type' => 'boolean' }
        when :decimal then { 'type' => 'string', 'pattern' => DECIMAL_PATTERN }
        when :money then { 'type' => 'string', 'format' => 'money', 'pattern' => DECIMAL_PATTERN }
        when :id
          prefix = Spree::Preferences::Preferable.preference_model(definition)._prefix_id_prefix
          { 'type' => 'string', 'format' => 'prefixed-id', 'pattern' => "^#{prefix}_[A-Za-z0-9]+$", 'x-spree-prefix' => prefix }
        when :object
          properties = definition[:properties].to_h { |name, type| [name.to_s, item_schema(type, {})] }
          { 'type' => 'object', 'properties' => properties, 'required' => properties.keys, 'additionalProperties' => false }
        else
          {}
        end
      end

      def self.string_schema(format)
        { 'type' => 'string' }.merge(FORMATS.fetch(format, {}).transform_keys(&:to_s))
      end

      # The default in the form the API returns it: decimals as exact strings.
      def self.wire_default(default, definition)
        return default if default.nil?
        return BigDecimal(default.to_s, exception: false)&.as_json if definition[:type] == :decimal

        default.as_json
      end

      private_class_method :property, :value_schema, :item_schema, :string_schema, :wire_default
    end
  end
end
