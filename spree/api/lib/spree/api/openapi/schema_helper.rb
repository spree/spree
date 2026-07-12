# frozen_string_literal: true

module Spree
  module Api
    module OpenAPI
      # Helper module to reference Typelizer-generated schemas in rswag specs
      module SchemaHelper
        extend self

        # Reference a schema by name (e.g., 'Product', 'Order')
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
                refresh_token: { type: :string, description: 'Refresh token for obtaining new access tokens' },
                user: { '$ref' => '#/components/schemas/Customer' }
              },
              required: %w[token refresh_token user]
            },
            PermissionRule: {
              type: :object,
              description: 'A single permission rule (CanCanCan rule). Rules are applied in order, last-matching-wins.',
              properties: {
                allow: { type: :boolean, description: 'true for `can`, false for `cannot`' },
                actions: { type: :array, items: { type: :string }, description: 'Action names, e.g. ["read", "update"] or ["manage"]' },
                subjects: { type: :array, items: { type: :string }, description: 'Subject class names, e.g. ["Spree::Product"] or ["all"]' },
                has_conditions: { type: :boolean, description: 'True if the server-side rule has per-record conditions. The SPA shows the action optimistically and handles 403 from the API.' }
              },
              required: %w[allow actions subjects has_conditions]
            },
            MeResponse: {
              type: :object,
              description: 'Current admin user profile and serialized permissions',
              properties: {
                user: { '$ref' => '#/components/schemas/AdminUser' },
                permissions: { type: :array, items: { '$ref' => '#/components/schemas/PermissionRule' } }
              },
              required: %w[user permissions]
            },
            ImportSchemaField: {
              type: :object,
              description: 'A canonical column of an import type, including per-store custom field columns',
              properties: {
                name: { type: :string, description: 'Canonical field name used in mappings', example: 'slug' },
                label: { type: :string, description: 'Human-readable label', example: 'Slug' },
                required: { type: :boolean, description: 'Whether the field must be mapped before processing' }
              },
              required: %w[name label required]
            },
            CheckoutRequirement: {
              type: :object,
              properties: {
                step: { type: :string, description: 'Checkout step this requirement belongs to', example: 'payment' },
                field: { type: :string, description: 'Field that needs to be satisfied', example: 'payment' },
                message: { type: :string, description: 'Human-readable requirement message', example: 'Add a payment method' }
              },
              required: %w[step field message]
            },
            CartWarning: {
              type: :object,
              description: 'A warning about a cart issue (e.g., item removed due to stock change)',
              properties: {
                code: { type: :string, description: 'Machine-readable warning code', example: 'line_item_removed' },
                message: { type: :string, description: 'Human-readable warning message', example: 'Blue T-Shirt was removed because it was sold out' },
                line_item_id: { type: :string, nullable: true, description: 'Prefixed line item ID (when applicable)', example: 'li_abc123' },
                variant_id: { type: :string, nullable: true, description: 'Prefixed variant ID (when applicable)', example: 'variant_abc123' }
              },
              required: %w[code message]
            },
            FulfillmentManifestItem: {
              type: :object,
              description: 'An item within a fulfillment — which line item and how many units are in this fulfillment',
              properties: {
                item_id: { type: :string, description: 'Line item ID', example: 'li_abc123' },
                variant_id: { type: :string, description: 'Variant ID', example: 'variant_abc123' },
                quantity: { type: :integer, description: 'Quantity in this fulfillment', example: 2 }
              },
              required: %w[item_id variant_id quantity]
            },
            AdminUserRoleAssignment: {
              type: :object,
              description: 'A role assignment for the current store on a staff member',
              properties: {
                id: { type: :string, description: 'Prefixed role ID', example: 'role_abc123' },
                name: { type: :string, description: 'Role name', example: 'admin' }
              },
              required: %w[id name]
            },
            PreferenceField: {
              type: :object,
              description: 'A single configurable preference on a payment method, promotion rule/action, or calculator. The frontend uses `type` + `default` to render a sensible input.',
              properties: {
                key: { type: :string, example: 'amount_min' },
                type: { type: :string, example: 'decimal', description: 'string | text | password | integer | decimal | boolean | array | hash' },
                default: { description: 'Default value (any JSON type), null when there is no default', nullable: true }
              },
              required: %w[key type]
            },
            PromotionActionCalculator: {
              type: :object,
              description: "The action's nested calculator (when the action carries one — null for actions like `free_shipping`)",
              properties: {
                type: { type: :string, example: 'flat_rate', description: 'Wire shorthand for the calculator subclass' },
                label: { type: :string, example: 'Flat Rate' },
                preferences: { type: :object, additionalProperties: true },
                preference_schema: { type: :array, items: { '$ref' => '#/components/schemas/PreferenceField' } }
              },
              required: %w[type label preferences preference_schema]
            },
            PromotionActionLineItem: {
              type: :object,
              description: 'One row in a `create_line_items` action — the variant added to the order and how many',
              properties: {
                variant_id: { type: :string, example: 'variant_abc123' },
                quantity: { type: :integer, example: 1 }
              },
              required: %w[variant_id quantity]
            }
          }
        end

        # Get all store schemas (Typelizer + common)
        def all_schemas
          schemas = common_schemas

          begin
            schemas.merge!(typelizer_schemas(:store))
          rescue StandardError => e
            Rails.logger.warn "Failed to load Typelizer schemas: #{e.message}"
          end

          schemas
        end

        # Get all admin schemas (Typelizer + common)
        def admin_schemas
          schemas = common_schemas

          # Override AuthResponse for admin: reference AdminUser, and drop refresh_token from the body
          # (admin sets the refresh token as an HttpOnly cookie, not in the JSON response).
          schemas[:AuthResponse] = {
            type: :object,
            properties: {
              token: { type: :string, description: 'JWT access token' },
              user: { '$ref' => '#/components/schemas/AdminUser' }
            },
            required: %w[token user]
          }

          begin
            schemas.merge!(typelizer_schemas(:admin))
          rescue StandardError => e
            Rails.logger.warn "Failed to load Typelizer admin schemas: #{e.message}"
          end

          schemas
        end

        private

        def typelizer_schemas(writer_name)
          with_typelizer_enabled do
            schemas = Typelizer.openapi_schemas(writer_name: writer_name)
            schemas.each_value do |s|
              s[:'x-typelizer'] = true
              strip_null_from_enums(s)
            end
            patch_cart_schema(schemas)
            patch_fulfillment_schema(schemas)
            patch_admin_user_schema(schemas)
            patch_promotion_rule_schema(schemas)
            patch_promotion_action_schema(schemas)
            patch_price_rule_schema(schemas)
            patch_import_schema(schemas)
            schemas
          end
        end

        # Same Array<{...}> issue as cart/fulfillment — patch Import#schema_fields
        # to reference the ImportSchemaField component schema.
        def patch_import_schema(schemas)
          import = schemas['Import'] || schemas[:Import]
          return unless import

          props = import[:properties]
          return unless props

          fields_key = props.key?('schema_fields') ? 'schema_fields' : :schema_fields
          if props[fields_key]
            props[fields_key] = {
              type: :array,
              items: { '$ref' => '#/components/schemas/ImportSchemaField' }
            }
          end
        end

        # Typelizer cannot represent Array<{...}> inline object types in OpenAPI,
        # so we patch them to reference manually-defined component schemas.
        def patch_cart_schema(schemas)
          cart = schemas['Cart'] || schemas[:Cart]
          return unless cart

          props = cart[:properties]
          return unless props

          req_key = props.key?('requirements') ? 'requirements' : :requirements
          if props[req_key]
            props[req_key] = {
              type: :array,
              items: { '$ref' => '#/components/schemas/CheckoutRequirement' }
            }
          end

          warn_key = props.key?('warnings') ? 'warnings' : :warnings
          if props[warn_key]
            props[warn_key] = {
              type: :array,
              items: { '$ref' => '#/components/schemas/CartWarning' }
            }
          end
        end

        # Same Array<{...}> issue as cart/fulfillment — patch AdminUser#roles
        # to reference the AdminUserRoleAssignment component schema.
        def patch_admin_user_schema(schemas)
          admin_user = schemas['AdminUser'] || schemas[:AdminUser]
          return unless admin_user

          props = admin_user[:properties]
          return unless props

          roles_key = props.key?('roles') ? 'roles' : :roles
          if props[roles_key]
            props[roles_key] = {
              type: :array,
              items: { '$ref' => '#/components/schemas/AdminUserRoleAssignment' }
            }
          end
        end

        # Same Array<{...}> + Array<string> typelize hints that Typelizer
        # collapses to `object` in OpenAPI. Patch the affected properties to
        # their correct array shapes.
        def patch_promotion_rule_schema(schemas)
          rule = schemas['PromotionRule'] || schemas[:PromotionRule]
          return unless rule

          patch_id_arrays(rule, %w[product_ids category_ids customer_ids])
          patch_preference_schema(rule)
        end

        def patch_price_rule_schema(schemas)
          rule = schemas['PriceRule'] || schemas[:PriceRule]
          return unless rule

          patch_preference_schema(rule)
        end

        def patch_promotion_action_schema(schemas)
          action = schemas['PromotionAction'] || schemas[:PromotionAction]
          return unless action

          patch_preference_schema(action)

          props = action[:properties]
          return unless props

          calc_key = props.key?('calculator') ? 'calculator' : :calculator
          if props[calc_key]
            props[calc_key] = {
              allOf: [{ '$ref' => '#/components/schemas/PromotionActionCalculator' }],
              nullable: true
            }
          end

          items_key = props.key?('line_items') ? 'line_items' : :line_items
          if props[items_key]
            props[items_key] = {
              type: :array,
              items: { '$ref' => '#/components/schemas/PromotionActionLineItem' },
              nullable: true
            }
          end
        end

        def patch_id_arrays(schema, keys)
          props = schema[:properties]
          return unless props

          keys.each do |key|
            actual = props.key?(key) ? key : key.to_sym
            next unless props[actual]

            props[actual] = {
              type: :array,
              items: { type: :string },
              nullable: true
            }
          end
        end

        def patch_preference_schema(schema)
          props = schema[:properties]
          return unless props

          key = props.key?('preference_schema') ? 'preference_schema' : :preference_schema
          return unless props[key]

          props[key] = {
            type: :array,
            items: { '$ref' => '#/components/schemas/PreferenceField' }
          }
        end

        # Typelizer cannot represent Array<{...}> inline object types in OpenAPI,
        # so we patch Fulfillment#items to reference the FulfillmentManifestItem component schema.
        def patch_fulfillment_schema(schemas)
          fulfillment = schemas['Fulfillment'] || schemas[:Fulfillment]
          return unless fulfillment

          props = fulfillment[:properties]
          return unless props

          items_key = props.key?('items') ? 'items' : :items
          if props[items_key]
            props[items_key] = {
              type: :array,
              items: { '$ref' => '#/components/schemas/FulfillmentManifestItem' }
            }
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
