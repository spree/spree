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
                count: { type: :integer, example: 100 },
                pages: { type: :integer, example: 4 }
              },
              required: %w[page limit count pages]
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
            schemas.each_value { |s| s[:'x-typelizer'] = true }
            schemas
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
