# frozen_string_literal: true

module Spree
  module Api
    module OpenAPI
      # Converts Typelizer interface data to OpenAPI 3.0 schemas
      # This allows us to generate OpenAPI schemas from the same Alba serializers
      # that generate TypeScript types, keeping them in sync.
      class TypelizerConverter
        # Force enable Typelizer for schema generation
        # Typelizer is normally disabled in test/production, but we need it
        # to generate OpenAPI schemas
        def self.with_typelizer_enabled
          original_env = ENV['DISABLE_TYPELIZER']
          ENV['DISABLE_TYPELIZER'] = 'false'
          yield
        ensure
          ENV['DISABLE_TYPELIZER'] = original_env
        end

        TYPESCRIPT_TO_OPENAPI_TYPES = {
          'string' => { type: :string },
          'number' => { type: :number },
          'boolean' => { type: :boolean },
          'null' => { type: :string, nullable: true },
          'unknown' => { type: :object },
          'any' => { type: :object }
        }.freeze

        class << self
          # Generate OpenAPI schemas hash from all Typelizer serializers
          def generate_schemas
            schemas = {}

            interfaces.each do |interface|
              name = interface.name
              schemas[name] = interface_to_schema(interface)
            end

            schemas
          end

          # Get all Typelizer interfaces
          # Note: No caching to ensure fresh schemas when serializers change
          def interfaces
            load_serializers
            context = ::Typelizer::WriterContext.new
            serializers = target_serializers

            serializers.map { |klass| context.interface_for(klass) }
          end

          # Convert a single interface to OpenAPI schema
          def interface_to_schema(interface)
            schema = {
              type: :object,
              properties: {},
              'x-typelizer': true
            }

            required = []

            # Get typelize hints from the serializer class for nullable overrides
            typelize_hints = {}
            if interface.serializer.respond_to?(:_typelizer_attributes)
              typelize_hints = interface.serializer._typelizer_attributes || {}
            end

            interface.properties.each do |prop|
              # Check if typelize hint indicates nullable
              hint = typelize_hints[prop.name.to_sym]
              nullable_from_hint = hint && hint[:type].to_s.include?('| null')

              prop_schema = property_to_schema(prop, nullable_override: nullable_from_hint)
              schema[:properties][prop.name.to_sym] = prop_schema

              # Track required fields (non-optional, non-nullable)
              is_nullable = prop.optional || prop_schema[:nullable] || nullable_from_hint
              required << prop.name unless is_nullable
            end

            schema[:required] = required if required.any?
            schema
          end

          # Convert a Typelizer property to OpenAPI property schema
          def property_to_schema(prop, nullable_override: false)
            # Get the type - can be an Interface object or a string
            type_value = prop.type

            # Determine if nullable from prop or override
            is_nullable = prop.nullable || nullable_override

            # Handle Interface types (associations to other serializers)
            if type_value.respond_to?(:name) && type_value.is_a?(::Typelizer::Interface)
              ref = { '$ref' => "#/components/schemas/#{type_value.name}" }
              if prop.multi
                schema = { type: :array, items: ref }
                schema[:nullable] = true if is_nullable
              elsif is_nullable
                # OpenAPI 3.0: nullable $ref needs allOf wrapper
                schema = { allOf: [ref], nullable: true }
              else
                schema = ref
              end
              return schema
            end

            # Get type string - handle both direct strings and other objects
            type_string = type_value.to_s.strip

            # Handle union types (e.g., "string | null", "number | null")
            if type_string.include?('|')
              schema = parse_union_type(type_string, prop)
              schema = { type: :array, items: schema } if prop.multi && schema[:type]&.to_s != 'array'
              return schema
            end

            # Handle array types (e.g., "Array<string>", "string[]")
            if type_string.match?(/Array<(.+)>/) || type_string.end_with?('[]')
              return parse_array_type(type_string, prop)
            end

            # Handle Record<K, V> types (TypeScript generic for key-value objects)
            if type_string.match?(/^Record</)
              schema = { type: :object }
              schema = { type: :array, items: schema } if prop.multi
              schema[:nullable] = true if prop.nullable
              return schema
            end

            # Handle basic types
            if TYPESCRIPT_TO_OPENAPI_TYPES.key?(type_string)
              schema = TYPESCRIPT_TO_OPENAPI_TYPES[type_string].dup
              schema = { type: :array, items: schema } if prop.multi
              schema[:nullable] = true if prop.nullable
              return schema
            end

            # Handle references to other types (serializer associations)
            if type_string.match?(/^[A-Z]/)
              ref = { '$ref' => "#/components/schemas/#{type_string}" }
              if prop.multi
                schema = { type: :array, items: ref }
                schema[:nullable] = true if prop.nullable
              elsif prop.nullable
                # OpenAPI 3.0: nullable $ref needs allOf wrapper
                schema = { allOf: [ref], nullable: true }
              else
                schema = ref
              end
              return schema
            end

            # Default to object
            schema = { type: :object }
            schema = { type: :array, items: schema } if prop.multi
            schema[:nullable] = true if prop.nullable
            schema
          end

          private

          def parse_union_type(type_string, prop)
            types = type_string.split('|').map(&:strip)

            # Check if nullable
            nullable = types.include?('null') || types.include?('undefined')
            types = types.reject { |t| t == 'null' || t == 'undefined' }

            if types.size == 1
              schema = property_type_to_schema(types.first, nullable: nullable)
              return schema
            end

            # Multiple non-null types - use oneOf
            {
              oneOf: types.map { |t| property_type_to_schema(t) },
              nullable: nullable || nil
            }.compact
          end

          def parse_array_type(type_string, prop)
            # Extract inner type from Array<T> or T[]
            inner_type = if type_string.match(/Array<(.+)>/)
                          Regexp.last_match(1)
                        else
                          type_string.sub(/\[\]$/, '')
                        end

            {
              type: :array,
              items: property_type_to_schema(inner_type)
            }
          end

          def property_type_to_schema(type_string, nullable: false)
            type_string = type_string.strip

            if TYPESCRIPT_TO_OPENAPI_TYPES.key?(type_string)
              schema = TYPESCRIPT_TO_OPENAPI_TYPES[type_string].dup
              schema[:nullable] = true if nullable
              return schema
            end

            # Reference type - in OpenAPI 3.0, nullable $ref needs allOf wrapper
            if type_string.match?(/^[A-Z]/)
              ref = { '$ref' => "#/components/schemas/#{type_string}" }
              if nullable
                return { allOf: [ref], nullable: true }
              end
              return ref
            end

            schema = { type: :object }
            schema[:nullable] = true if nullable
            schema
          end

          def load_serializers
            # Ensure Typelizer is enabled when loading serializers so the
            # typelize DSL actually stores type information
            original_env = ENV['DISABLE_TYPELIZER']
            ENV['DISABLE_TYPELIZER'] = 'false'

            # Force reload of serializers with Typelizer enabled
            ::Typelizer.dirs.flat_map { |dir| Dir["#{dir}/**/*.rb"] }.each do |file|
              load file
            end
          ensure
            ENV['DISABLE_TYPELIZER'] = original_env
          end

          def target_serializers
            base_classes = ::Typelizer.base_classes.filter_map do |base_class|
              Object.const_get(base_class) if Object.const_defined?(base_class)
            end

            return [] if base_classes.none?

            (base_classes + base_classes.flat_map(&:descendants)).uniq
              .reject { |serializer| ::Typelizer.reject_class.call(serializer: serializer) }
              .select { |s| s.name&.start_with?('Spree::Api::V3::') }
              .sort_by(&:name)
          end
        end
      end
    end
  end
end
