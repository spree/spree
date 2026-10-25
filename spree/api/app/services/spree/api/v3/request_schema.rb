module Spree
  module Api
    module V3
      # What one write endpoint accepts, declared once. The controller permits
      # from it, the API reference documents it, and the SDK request types are
      # generated from the reference, so the three cannot disagree.
      #
      #   request_params :product do |body|
      #     body.attribute :name, :string, required: true, on: :create
      #     body.attribute :status, :string, choices: Spree::Product::STATUSES, open: true
      #     body.attribute :category_ids, :array, of: :id
      #     body.attribute :metadata, :hash
      #     body.attribute :prices, :array, of: Spree::Api::V3::PriceRequestSchema
      #     body.attribute :options, :array do |option|
      #       option.attribute :name, :string, required: true
      #     end
      #   end
      #
      # The vocabulary is the `preference` one: a type symbol, `of:` for what
      # an `:array` holds, `choices:` for a closed list (`open: true` when
      # extensions may extend it), `:hash` for any keys. `required: true` is
      # required on both actions; add `on: :create` to require it when
      # creating only. `only: :create` (or `:update`) accepts the field on one
      # action alone. `permit: false` documents a field the controller reads
      # from the raw params itself. `format:` documents a string's format
      # (`email`, `uri`). `deprecated: 'Use country_code. Removed in 6.1.'`
      # keeps a field working while the API reference and the SDK types flag it.
      class RequestSchema
        KINDS = {
          string: { type: :string },
          integer: { type: :integer },
          # Measurements a client sends as JSON numbers (weights, dimensions,
          # coordinates). Money is never a number: use `decimal`.
          number: { type: :number },
          # Amounts, rates and quantities with decimals travel as canonical
          # decimal strings, never JSON numbers (see Spree::Money::Rounding).
          decimal: { type: :string, format: :decimal, pattern: '^-?\d+(\.\d+)?$' },
          boolean: { type: :boolean },
          date: { type: :string, format: :date },
          datetime: { type: :string, format: :'date-time' },
          id: { type: :string },
          any: {},
          # Codes from the closed lists below.
          country: { type: :string },
          currency: { type: :string },
          locale: { type: :string },
          weight_unit: { type: :string },
          dimension_unit: { type: :string }
        }.freeze

        # The closed lists a code field takes, published once per API as a
        # named component — the same `CountryCode`, `CurrencyCode` and
        # `WeightUnit` types the serializers declare, so a value read from a
        # response is the type a request takes.
        CODE_LISTS = {
          country: ['CountryCode', -> { Spree::IsoData.country_codes }],
          currency: ['CurrencyCode', -> { Spree::Money::Rounding::CURRENCY_CODES }],
          locale: ['LocaleCode', -> { Spree::Locales::ALL }],
          weight_unit: ['WeightUnit', -> { Spree::Variant::WEIGHT_UNITS }],
          dimension_unit: ['DimensionUnit', -> { Spree::Variant::DIMENSION_UNITS }]
        }.freeze

        ACTIONS = %i[create update].freeze

        OPEN_LIST_NOTE = 'The values listed are the built-in ones; extensions may add more.'.freeze

        class Field
          attr_reader :name, :kind, :array, :required, :nullable, :description, :example, :enum, :open, :only, :schema,
                      :permit, :format, :deprecated

          def initialize(name, kind, array: false, required: false, nullable: false, description: nil,
                         example: nil, enum: nil, open: false, only: nil, schema: nil, permit: true, format: nil,
                         deprecated: nil)
            raise ArgumentError, "deprecated: says what to use instead (#{name})" if deprecated == true

            raise ArgumentError, "open: needs an enum: list of the built-in values (#{name})" if open && enum.nil?

            unless required.in?([true, false, :create])
              raise ArgumentError, "required: must be true, false or :create (#{name})"
            end
            raise ArgumentError, "only: must be :create or :update (#{name})" if only && !only.in?(ACTIONS)

            @name = name.to_sym
            @kind = kind
            @array = array
            @required = required
            @nullable = nullable
            @description = description
            @example = example
            @enum = enum&.map(&:to_s)
            @open = open
            @only = only
            @schema = schema
            @permit = permit
            @format = format
            @deprecated = deprecated
          end

          # @param action [Symbol, nil]
          def accepted_on?(action)
            only.nil? || action.nil? || only == action
          end

          # @param action [Symbol, nil]
          def required_on?(action)
            required == true || (required == :create && action == :create)
          end

          # This field, required on `on` (`:create`) or always. A field
          # already required always stays required always.
          #
          # @param on [Symbol, nil] `:create`, or nil for every action
          # @return [Field]
          def required_copy(on)
            copy = dup
            copy.instance_variable_set(:@required, required == true ? true : on || true)
            copy
          end

          # A hash of any keys, such as `metadata` or `provider_settings`.
          def free_object?
            kind == :object && schema.nil?
          end
        end

        attr_reader :name, :fields, :base

        # The types an attribute takes: the scalars above, plus `:hash` (any
        # keys), `:object` (a block or a `shape:`) and `:array` (`of:` a type
        # or a shape, or a block of fields).
        TYPES = (KINDS.keys + %i[hash object array]).freeze

        # A shape shared between several endpoints (a price, an address),
        # published as its own component so each SDK has one type for it.
        #
        # @param name [String] the component name, such as `PriceParams`
        # @return [RequestSchema]
        def self.shape(name, &block)
          raise ArgumentError, "a shape's name ends in Params (#{name})" unless name.to_s.end_with?('Params')

          new(name, &block)
        end

        # A shape several endpoints share is a class in app/request_schemas,
        # declared the way a model declares its attributes:
        #
        #   class Spree::Api::V3::PriceRequestSchema < Spree::Api::V3::RequestSchema
        #     publishes 'PriceParams'
        #
        #     attribute :currency, :currency, required: true
        #   end
        #
        # A subclass starts from its parent's attributes, so the Admin API's
        # address extends the shared one. Without `publishes` the class is a
        # set of attributes other declarations include rather than a type of
        # its own.
        class << self
          # @param name [String] the component name, ending in `Params`
          def publishes(name)
            raise ArgumentError, "a shape's name ends in Params (#{name})" unless name.to_s.end_with?('Params')
            raise ArgumentError, "#{self.name}: `publishes` goes before the attributes" if @definition

            @published_name = name.to_s
          end

          # @return [RequestSchema] what the class declares
          def definition
            @definition ||= new(@published_name).tap do |schema|
              schema.include_attributes(superclass) if superclass < RequestSchema
            end
          end

          # @param value [RequestSchema, Class] an instance or a declared class
          # @return [RequestSchema, nil]
          def resolve(value)
            value.is_a?(Class) ? value.definition : value
          end

          %i[attribute extends include_attributes require_attributes external_references].each do |method|
            define_method(method) { |*args, **options, &block| definition.public_send(method, *args, **options, &block) }
          end
        end

        # @param name [String, Symbol, nil] the resource, `product` publishing
        #   `ProductCreateParams` and `ProductUpdateParams`; or a name ending
        #   in `Params`, published as given for every action
        # @yieldparam schema [RequestSchema] the schema, to declare attributes on
        def initialize(name = nil)
          @name = name&.to_s
          @fields = {}
          yield self if block_given?
        end

        # Declares one attribute of the body.
        #
        # @param name [Symbol]
        # @param type [Symbol] one of TYPES
        # @param of [Symbol, Class, RequestSchema, nil] what an `:array` holds:
        #   a scalar type, or a shared shape
        # @param shape [Class, RequestSchema, nil] what an `:object` holds
        # @param as [String, nil] publishes a block's object (or the objects
        #   of an `:array`) as a component of this name
        # @param choices [Array, nil] the values the attribute takes
        # @param required [Boolean]
        # @param on [Symbol, nil] `:create` to require it only when creating
        # @yieldparam schema [RequestSchema] a nested object's attributes
        def attribute(name, type, of: nil, shape: nil, as: nil, choices: nil, required: false, on: nil, **options, &block)
          raise ArgumentError, "#{name}: unknown type #{type.inspect}; use one of #{TYPES.join(', ')}" unless TYPES.include?(type)
          raise ArgumentError, "#{name}: `on:` scopes `required: true` and is `:create`" if on && (!required || on != :create)

          options = options.merge(required: on || required, enum: choices)
          nested = nested_schema(type, of: of, shape: shape, as: as, &block)

          case type
          when :array then add_array(name, of, nested, options)
          when :object
            raise ArgumentError, "#{name}: an :object needs a block or `shape:`; use :hash for any keys" unless nested

            add(Field.new(name, :object, schema: nested, **options))
          when :hash then add(Field.new(name, :object, **options))
          else add(Field.new(name, type, **options))
          end
        end

        # The identities a record has in external systems, which the Admin API
        # reads from the raw params (Admin::Concerns::ExternalReferences).
        def external_references
          attribute :external_references, :hash, permit: false, description: <<~TEXT.squish
            Identities the record has in external systems, keyed by system: the same
            `{ system: external_id }` map the Admin API renders, so what you read can be
            sent straight back. Systems you do not name keep the reference they have.
            A list of `{ system, external_id }` entries is accepted too.
          TEXT
        end

        # Builds on a published shape: the body accepts all of its attributes,
        # and the published type is that shape's type plus what this schema
        # adds, so clients write one type wherever the shape is accepted.
        #
        # @param other [RequestSchema, Class] a shape with a published name
        def extends(other)
          parent = RequestSchema.resolve(other)
          raise ArgumentError, "#{parent.class.name} has no published name to extend" unless shape?(parent)

          include_attributes(parent)
          @base = parent
        end

        # Adds the attributes of another schema, for endpoints that extend a
        # shared set.
        #
        # @param other [RequestSchema, Class]
        def include_attributes(other)
          RequestSchema.resolve(other).fields.each_value { |field| add(field) }
        end

        # Marks attributes this schema took from another as required, for an
        # endpoint whose model needs what the shared set leaves optional.
        #
        # @param names [Array<Symbol>]
        # @param on [Symbol, nil] `:create` to require them only when creating
        # @return [void]
        def require_attributes(*names, on: nil)
          raise ArgumentError, '`on:` is :create' if on && on != :create

          names.each do |name|
            field = fields.fetch(name) { raise ArgumentError, "#{name} is not an attribute of this schema" }
            fields[name] = field.required_copy(on)
          end
          @permit_lists = nil
        end

        # Replaces the description of an attribute this schema took from
        # another, for an endpoint where it behaves differently.
        #
        # @param name [Symbol]
        # @param description [String]
        # @return [void]
        def describe_attribute(name, description)
          field = fields.fetch(name) { raise ArgumentError, "#{name} is not an attribute of this schema" }
          copy = field.dup
          copy.instance_variable_set(:@description, description)
          fields[name] = copy
        end

        # The `params.permit` list for an action.
        #
        # @param action [Symbol, String, nil] `create` or `update`; nil
        #   accepts every field
        # @return [Array<Symbol, Hash>]
        def permit_list(action = nil)
          action = action&.to_sym
          (@permit_lists ||= {})[action] ||= build_permit_list(action).freeze
        end

        # The JSON Schema of the request body for an action.
        #
        # @param action [Symbol, String, nil]
        # @return [Hash]
        def json_schema(action = nil)
          action = action&.to_sym
          # A base field this action does not take would still reach clients
          # through the base's type, so such a body is published in full.
          unless base && base.fields.each_value.all? { |field| field.accepted_on?(action) }
            return object_schema(fields_for(action), action)
          end

          # Attributes the base describes the same way for this action are
          # left to its type.
          own = fields_for(action).reject do |field|
            inherited = base.fields[field.name]
            inherited && inherited.required_on?(action) == field.required_on?(action) &&
              property_schema(inherited) == property_schema(field)
          end
          reference = { '$ref': "#/components/schemas/#{base.name}" }
          own.any? ? { allOf: [reference, object_schema(own, action)] } : reference
        end

        # The component name published for an action.
        #
        # @param action [Symbol, String]
        # @return [String]
        def component_name(action)
          return name if name.end_with?('Params')

          "#{name.camelize}#{action.to_s.camelize}Params"
        end

        # Every named shape this schema reaches, nested ones included.
        #
        # @return [Array<RequestSchema>]
        def shapes
          (base ? [base, *base.shapes] : []).concat(fields.each_value.flat_map do |field|
            next [] unless field.schema

            nested = field.schema.shapes
            shape?(field.schema) ? [field.schema, *nested] : nested
          end).uniq
        end

        # The code lists this schema's fields reach, nested ones included,
        # as the components they publish.
        #
        # @return [Hash{String => Hash}]
        def code_lists
          fields.each_value.each_with_object({}) do |field, lists|
            lists.merge!(field.schema.code_lists) if field.schema
            next unless CODE_LISTS.key?(field.kind)

            name, values = CODE_LISTS[field.kind]
            lists[name] = { type: :string, enum: values.call }
          end
        end

        def shape?(schema)
          schema.name.present?
        end

        private

        def nested_schema(type, of:, shape:, as:, &block)
          return RequestSchema.resolve(shape) if shape
          return RequestSchema.resolve(of) if of.is_a?(Class) || of.is_a?(RequestSchema)
          return unless block

          as ? RequestSchema.shape(as, &block) : RequestSchema.new(&block)
        end

        def add_array(name, of, nested, options)
          return add(Field.new(name, :object, schema: nested, array: true, **options)) if nested

          unless of.is_a?(Symbol) && KINDS.key?(of)
            raise ArgumentError, "#{name}: an :array needs `of:` a scalar type or a shape, or a block of attributes"
          end
          # Rails permits a list of scalars, never a list of any-key hashes.
          if of == :any && options.fetch(:permit, true)
            raise ArgumentError, "#{name}: a list of :any values cannot be permitted; declare its items or use `permit: false`"
          end

          add(Field.new(name, of, array: true, **options))
        end

        def add(field)
          raise ArgumentError, "#{field.name} is declared twice" if fields.key?(field.name)

          @permit_lists = nil
          fields[field.name] = field
        end

        def build_permit_list(action)
          scalars = []
          nested = []

          fields_for(action).each do |field|
            next unless field.permit

            if field.schema
              nested << { field.name => field.schema.permit_list }
            elsif field.free_object?
              nested << { field.name => {} }
            elsif field.kind == :any
              # A value of any JSON type: a scalar, a list or a hash.
              scalars << field.name
              nested << { field.name => [] } << { field.name => {} }
            elsif field.array
              nested << { field.name => [] }
            else
              scalars << field.name
            end
          end

          scalars + nested
        end


        def object_schema(fields, action)
          required = fields.select { |field| field.required_on?(action) }.map { |field| field.name.to_s }

          schema = { type: :object, properties: fields.to_h { |field| [field.name, property_schema(field)] } }
          schema[:required] = required if required.any?
          schema
        end

        def fields_for(action)
          fields.values.select { |field| field.accepted_on?(action) }
        end

        def property_schema(field)
          item = item_schema(field)
          description = [field.description, (OPEN_LIST_NOTE if field.open), deprecation_note(field)].compact.join(' ').presence
          documentation = { description: description, example: field.example }.compact
          documentation[:deprecated] = true if field.deprecated

          if field.array
            schema = { type: :array, items: item }.merge(documentation)
            schema[:nullable] = true if field.nullable
            return schema
          end

          # A $ref ignores the keys beside it, so a described or nullable
          # reference wraps it.
          if item.key?(:$ref) && (documentation.any? || field.nullable)
            item = { allOf: [item] }
          end

          item = item.merge(documentation)
          item[:nullable] = true if field.nullable
          item
        end

        def deprecation_note(field)
          "Deprecated: #{field.deprecated}" if field.deprecated
        end

        def item_schema(field)
          return { '$ref': "#/components/schemas/#{CODE_LISTS[field.kind].first}" } if CODE_LISTS.key?(field.kind)

          if field.schema
            return { '$ref': "#/components/schemas/#{field.schema.name}" } if shape?(field.schema)

            return field.schema.json_schema
          end
          return { type: :object, additionalProperties: true } if field.free_object?

          schema = KINDS.fetch(field.kind).dup
          schema[:format] = field.format if field.format
          return schema unless field.enum
          return schema.merge(enum: field.enum) unless field.open

          # The same open list the serializers publish (`enum_type_name`):
          # clients autocomplete the built-in values and still accept any other.
          { anyOf: [schema.merge(enum: field.enum), schema] }
        end
      end
    end
  end
end
