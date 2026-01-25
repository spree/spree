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
                      additionalProperties: {
                        type: :array,
                        items: { type: :string }
                      },
                      nullable: true
                    }
                  },
                  required: %w[code message]
                }
              },
              required: %w[error]
            },
            AuthResponse: {
              type: :object,
              properties: {
                token: { type: :string, description: 'JWT access token' },
                user: { '$ref' => '#/components/schemas/StoreUser' }
              },
              required: %w[token user]
            }
          }
        end

        # Get all schemas (Typelizer + common)
        def all_schemas
          schemas = common_schemas

          begin
            schemas.merge!(TypelizerConverter.generate_schemas)
          rescue StandardError => e
            Rails.logger.warn "Failed to load Typelizer schemas: #{e.message}"
          end

          schemas
        end
      end
    end
  end
end
