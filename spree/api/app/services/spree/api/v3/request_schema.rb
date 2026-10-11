module Spree
  module Api
    module V3
      # What one write endpoint accepts, declared once. The controller permits
      # from it, the API reference documents it, and the SDK request types are
      # generated from the reference, so the three cannot disagree.
      #
      #   request_params :product do
      #     string :name, required: :create
      #     string :status, enum: %w[draft active archived]
      #     id :category_ids, array: true
      #     object :metadata
      #     object :prices, array: true, shape: Spree::Api::V3::PriceRequestSchema
      #     object :options, array: true do
      #       string :name, :value, required: true
      #     end
      #   end
      #
      # `required: :create` is required when creating and optional when
      # updating; `required: true` is required in both. `only: :create` (or
      # `:update`) accepts a field on one of the two actions alone.
      # `permit: false` documents a field the controller reads from the raw
      # params itself (external references, uploads), so it is left out of
      # the permit list. `format:` documents a string's format (`email`, `uri`).
      # `open: true` marks an `enum:` list extensions may extend (statuses,
      # fee kinds), matching how the serializers publish the same field.
      # `deprecated: 'Use country_code. Removed in 6.1.'` keeps a field
      # working while the API reference and the SDK types flag it.
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
          # ISO codes, from the closed lists below.
          country: { type: :string },
          currency: { type: :string }
        }.freeze

        # The ISO lists a `country` or `currency` field takes, published once
        # per API as a named component — the same `CountryCode` and
        # `CurrencyCode` types the serializers declare, so a value read from
        # a response is the type a request takes.
        CODE_LISTS = {
          country: ['CountryCode', -> { Spree::IsoData.country_codes }],
          currency: ['CurrencyCode', -> { Spree::Money::Rounding::CURRENCY_CODES }]
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

          # A hash of any keys, such as `metadata` or `provider_settings`.
          def free_object?
            kind == :object && schema.nil?
          end
        end

        attr_reader :name, :fields

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
        # declared the way a serializer is:
        #
        #   class Spree::Api::V3::PriceRequestSchema < Spree::Api::V3::RequestSchema
        #     publishes 'PriceParams'
        #     string :currency, required: true
        #   end
        #
        # A subclass starts from its parent's fields, so the Admin API's
        # address extends the shared one. Without `publishes` the class is a
        # field set other declarations include rather than a type of its own.
        class << self
          # @param name [String] the component name, ending in `Params`
          def publishes(name)
            raise ArgumentError, "a shape's name ends in Params (#{name})" unless name.to_s.end_with?('Params')
            raise ArgumentError, "#{self.name}: `publishes` goes before the fields" if @definition

            @published_name = name.to_s
          end

          # @return [RequestSchema] what the class declares
          def definition
            @definition ||= new(@published_name).tap do |schema|
              schema.include_fields(superclass) if superclass < RequestSchema
            end
          end

          # @param value [RequestSchema, Class] an instance or a declared class
          # @return [RequestSchema, nil]
          def resolve(value)
            value.is_a?(Class) ? value.definition : value
          end

          (KINDS.keys + %i[object include_fields external_references]).each do |method|
            define_method(method) { |*args, **options, &block| definition.public_send(method, *args, **options, &block) }
          end
        end

        # @param name [String, Symbol, nil] the resource, `product` publishing
        #   `ProductCreateParams` and `ProductUpdateParams`; or a name ending
        #   in `Params`, published as given for every action
        def initialize(name = nil, &block)
          @name = name&.to_s
          @fields = {}
          instance_eval(&block) if block
        end

        KINDS.each_key do |kind|
          # @param names [Array<Symbol>] one or more fields of this kind
          define_method(kind) do |*names, **options|
            names.each { |field_name| add(Field.new(field_name, kind, **options)) }
          end
        end

        # A nested hash. Without a block or `shape:` it takes any keys.
        #
        # @param name [Symbol]
        # @param shape [RequestSchema, Class, nil] a shared shape
        # @param as [String, nil] publishes the block's fields as a component
        #   of this name, for a nested type clients want to name
        def object(name, shape: nil, as: nil, **options, &block)
          schema = RequestSchema.resolve(shape) || (block && (as ? RequestSchema.shape(as, &block) : RequestSchema.new(&block)))
          if options[:array] && schema.nil?
            raise ArgumentError, "#{name}: an array of objects needs a shape, since any-key hashes cannot be permitted in a list"
          end

          add(Field.new(name, :object, schema: schema, **options))
        end

        # The identities a record has in external systems, which the Admin API
        # reads from the raw params (Admin::Concerns::ExternalReferences).
        def external_references
          object :external_references, permit: false, description: <<~TEXT.squish
            Identities the record has in external systems, keyed by system: the same
            `{ system: external_id }` map the Admin API renders, so what you read can be
            sent straight back. Systems you do not name keep the reference they have.
            A list of `{ system, external_id }` entries is accepted too.
          TEXT
        end

        # Adds the fields of another schema, for endpoints that extend a
        # shared set.
        #
        # @param other [RequestSchema, Class]
        def include_fields(other)
          RequestSchema.resolve(other).fields.each_value { |field| add(field) }
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
          fields = fields_for(action)
          required = fields.select { |field| field.required_on?(action) }.map { |field| field.name.to_s }

          schema = { type: :object, properties: fields.to_h { |field| [field.name, property_schema(field)] } }
          schema[:required] = required if required.any?
          schema
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
          fields.each_value.flat_map do |field|
            next [] unless field.schema

            nested = field.schema.shapes
            shape?(field.schema) ? [field.schema, *nested] : nested
          end.uniq
        end

        # The ISO code lists this schema's fields reach, nested ones included,
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
