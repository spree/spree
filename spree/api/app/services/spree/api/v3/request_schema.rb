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
      #     object :prices, array: true, shape: RequestShapes::PRICE
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
          any: {}
        }.freeze

        ACTIONS = %i[create update].freeze

        class Field
          attr_reader :name, :kind, :array, :required, :nullable, :description, :example, :enum, :only, :schema, :permit,
                      :format

          def initialize(name, kind, array: false, required: false, nullable: false, description: nil,
                         example: nil, enum: nil, only: nil, schema: nil, permit: true, format: nil)
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
            @only = only
            @schema = schema
            @permit = permit
            @format = format
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
        # @param shape [RequestSchema, nil] a shared shape
        # @param as [String, nil] publishes the block's fields as a component
        #   of this name, for a nested type clients want to name
        def object(name, shape: nil, as: nil, **options, &block)
          schema = shape || (block && (as ? RequestSchema.shape(as, &block) : RequestSchema.new(&block)))
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
        # @param other [RequestSchema]
        def include_fields(other)
          other.fields.each_value { |field| add(field) }
        end

        # The `params.permit` list for an action.
        #
        # @param action [Symbol, String, nil] `create` or `update`; nil
        #   accepts every field
        # @return [Array<Symbol, Hash>]
        def permit_list(action = nil)
          action = action&.to_sym
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

        def shape?(schema)
          schema.name.present?
        end

        private

        def add(field)
          raise ArgumentError, "#{field.name} is declared twice" if fields.key?(field.name)

          fields[field.name] = field
        end

        def fields_for(action)
          fields.values.select { |field| field.accepted_on?(action) }
        end

        def property_schema(field)
          item = item_schema(field)
          documentation = { description: field.description, example: field.example }.compact

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

        def item_schema(field)
          if field.schema
            return { '$ref': "#/components/schemas/#{field.schema.name}" } if shape?(field.schema)

            return field.schema.json_schema
          end
          return { type: :object, additionalProperties: true } if field.free_object?

          schema = KINDS.fetch(field.kind).dup
          schema[:enum] = field.enum if field.enum
          schema[:format] = field.format if field.format
          schema
        end
      end
    end
  end
end
