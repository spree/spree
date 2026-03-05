# frozen_string_literal: true

module Spree
  module Api
    module OpenAPI
      # Helper module to reference Typelizer-generated schemas in rswag specs
      module SchemaHelper
        extend self

        # Reference a schema by name (e.g., 'StoreProduct', 'StoreOrder')
        def ref(schema_name)
          { '$ref' => "#/components/schemas/#{schema_name}" }
        end

        # Paginated response wrapper
        def paginated(schema_name)
          {
            type: :object,
            properties: {
              data: {
                type: :array,
                items: ref(schema_name)
              },
              meta: ref('PaginationMeta')
            },
            required: %w[data meta]
          }
        end

        # Error response schema
        def error_response
          ref('ErrorResponse')
        end

        # Common schemas that are not from serializers
        def common_schemas
          {
            PaginationMeta: {
              type: :object,
              properties: {
                page: { type: :integer, example: 1 },
                limit: { type: :integer, example: 25 },
                count: { type: :integer, example: 100, description: 'Total number of records' },
                pages: { type: :integer, example: 4, description: 'Total number of pages' },
                from: { type: :integer, example: 1, description: 'Index of first record on this page' },
                to: { type: :integer, example: 25, description: 'Index of last record on this page' },
                in: { type: :integer, example: 25, description: 'Number of records on this page' },
                previous: { type: :integer, nullable: true, example: nil, description: 'Previous page number' },
                next: { type: :integer, nullable: true, example: 2, description: 'Next page number' }
              },
              required: %w[page limit count pages from to in]
            },
            ErrorResponse: {
              type: :object,
              properties: {
                error: {
                  type: :object,
                  properties: {
                    code: { type: :string, example: 'record_not_found' },
                    message: { type: :string, example: 'Record not found' },
                    details: {
                      type: :object,
                      description: 'Field-specific validation errors',
                      nullable: true,
                      example: { name: ['is too short', 'is required'], email: ['is invalid'] }
                    }
                  },
                  required: %w[code message]
                }
              },
              required: %w[error],
              example: {
                error: {
                  code: 'validation_error',
                  message: 'Validation failed',
                  details: { name: ['is too short'], email: ['is invalid'] }
                }
              }
            },
            AuthResponse: {
              type: :object,
              properties: {
                token: { type: :string, description: 'JWT access token' },
                user: { '$ref' => '#/components/schemas/StoreCustomer' }
              },
              required: %w[token user]
            }
          }
        end

        # Get all schemas (Typelizer + common)
        def all_schemas
          schemas = common_schemas

          begin
            schemas.merge!(typelizer_schemas)
          rescue StandardError => e
            Rails.logger.warn "Failed to load Typelizer schemas: #{e.message}"
          end

          schemas
        end

        private

        def typelizer_schemas
          with_typelizer_enabled do
            schemas = Typelizer.openapi_schemas
            schemas = schemas.select { |key, _| key.to_s.start_with?('Store') }
            schemas.each_value do |s|
              s[:'x-typelizer'] = true
              strip_null_from_enums(s)
            end
            schemas
          end
        end

        # Typelizer adds nil to enum arrays for nullable fields.
        # OpenAPI 3.0 handles nullability via `nullable: true`, so the nil entry is redundant
        # and causes issues with code generators.
        def strip_null_from_enums(schema)
          properties = schema[:properties] || {}
          properties.each_value do |prop|
            next unless prop.is_a?(Hash) && prop[:enum].is_a?(Array)

            prop[:enum].reject!(&:nil?)
          end
        end

        # Typelizer is normally disabled in test/production, but we need it
        # enabled to generate OpenAPI schemas from serializer type hints
        def with_typelizer_enabled
          original = ENV['DISABLE_TYPELIZER']
          ENV['DISABLE_TYPELIZER'] = 'false'
          yield
        ensure
          ENV['DISABLE_TYPELIZER'] = original
        end
      end
    end
  end
end
