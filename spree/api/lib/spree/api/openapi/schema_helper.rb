# frozen_string_literal: true

require 'spree/api/preference_families'

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

        # A list that is not paginated
        def list(items)
          { type: :object, properties: { data: { type: :array, items: items } }, required: %w[data] }
        end

        # Error response schema
        def error_response
          ref('ErrorResponse')
        end

        # Common schemas that are not from serializers
        # The nested calculator of a promotion action and a delivery method,
        # keyed by the preference family its `preferences` belong to.
        CALCULATOR_SCHEMAS = {
          'PromotionCalculator' => [:PromotionActionCalculator, {
            type: :object,
            description: "The action's nested calculator (when the action carries one — null for actions like `free_shipping`)",
            properties: {
              type: { type: :string, example: 'flat_rate', description: 'Wire shorthand for the calculator subclass' },
              preferences: { '$ref' => '#/components/schemas/PromotionCalculatorPreferences' }
            },
            required: %w[type preferences]
          }],
          'DeliveryCalculator' => [:DeliveryMethodCalculator, {
            type: :object,
            description: 'How the delivery method prices a shipment',
            properties: {
              type: { type: :string, example: 'flat_rate', description: 'Wire shorthand for the calculator subclass' },
              preferences: { '$ref' => '#/components/schemas/DeliveryCalculatorPreferences' }
            },
            required: %w[type preferences]
          }]
        }.freeze

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
                subjects: { type: :array, items: { type: :string }, description: 'Subject short names, e.g. ["product"] or ["all"]' },
                has_conditions: { type: :boolean, description: 'True if the server-side rule has per-record conditions. The SPA shows the action optimistically and handles 403 from the API.' }
              },
              required: %w[allow actions subjects has_conditions]
            },
            PreferenceSchema: {
              type: :object,
              description: 'The JSON Schema (draft 2020-12) of a type\'s `preferences`: one property per setting, ' \
                           'with `format` (`money`, `currency`, `iso-country`, `prefixed-id`, …), `enum`, `default`, ' \
                           '`x-spree-secret` for a secret and `x-spree-prefix` for an id list. Unknown keys are refused.',
              additionalProperties: true,
              example: { type: 'object', properties: { amount: { type: 'string', format: 'money', default: '0.0' } }, additionalProperties: false }
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

          # Only here: it points at `AdminUser`, which no other branch
          # publishes — the store has no such user and a seller's team member
          # is `TeamMember`. Declared in the shared set it became an
          # unresolvable `$ref` in both of their specs.
          schemas[:MeResponse] = {
            type: :object,
            description: 'Current admin user profile and serialized permissions',
            properties: {
              user: { '$ref' => '#/components/schemas/AdminUser' },
              permissions: { type: :array, items: { '$ref' => '#/components/schemas/PermissionRule' } }
            },
            required: %w[user permissions]
          }

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

          # Written by hand: the payload is computed, so its serializer declares
          # no types to generate from.
          schemas[:ResourceTranslations] = {
            type: :object,
            description: "A record's translatable fields and their value in each locale",
            properties: {
              resource_id: { type: :string, example: 'prod_UkLWZg9DAJ' },
              resource_type: { type: :string, example: 'product' },
              translations: {
                type: :object,
                description: 'Keyed by locale. Each entry holds every field\'s translation, null where there is none, ' \
                             'and `translated_field_count`.',
                additionalProperties: { type: :object, additionalProperties: true },
                example: { de: { name: 'Espressomaschine', description: nil, translated_field_count: 1 } }
              },
              fields: {
                type: :array,
                description: 'The translatable fields and their value in the default locale. Present when reading a record.',
                items: {
                  type: :object,
                  properties: {
                    key: { type: :string, example: 'name' },
                    type: { type: :string, example: 'string', description: 'How the field is edited: `string` or `html`' },
                    source: { type: :string, nullable: true, example: 'Espresso Machine' }
                  },
                  required: %w[key type source]
                }
              },
              default_locale: { type: :string, example: 'en', description: 'Absent on nested `children`' },
              supported_locales: { type: :array, items: { type: :string }, example: %w[en de], description: 'Absent on nested `children`' },
              children: {
                type: :array,
                description: 'Nested translatable records, such as the option values of an option type',
                items: { '$ref' => '#/components/schemas/ResourceTranslations' }
              }
            },
            required: %w[resource_id resource_type translations]
          }

          begin
            schemas.merge!(typelizer_schemas(:admin))
          rescue StandardError => e
            Rails.logger.warn "Failed to load Typelizer admin schemas: #{e.message}"
          end

          add_preference_schemas(schemas, Spree::Api::PreferenceFamilies::REGISTRIES.keys)
        end

        # Get all seller schemas (Typelizer + common).
        #
        # The seller branch has no API-key credential, so its AuthResponse is
        # neither the store's nor the admin's: signing in returns the JWT, the
        # person who signed in, and the sellers they may act for — the panel
        # cannot make another request until it has picked one.
        def seller_schemas
          schemas = common_schemas

          schemas[:AuthResponse] = {
            type: :object,
            properties: {
              token: { type: :string, description: 'JWT access token, `seller_api` audience' },
              # `Account`, not `TeamMember`: the panel adopts the signed-in
              # person's saved language from this payload, which is what
              # carries the choice to a second browser.
              user: { '$ref' => '#/components/schemas/Account' },
              sellers: {
                type: :array,
                description: 'The sellers this user may act for. Pick one and send its `id` as `X-Spree-Seller-Id` on every subsequent request.',
                items: { '$ref' => '#/components/schemas/SellerSummary' }
              }
            },
            required: %w[token user sellers]
          }

          schemas.merge!(seller_common_schemas)

          begin
            schemas.merge!(typelizer_schemas(:seller))
          rescue StandardError => e
            Rails.logger.warn "Failed to load Typelizer seller schemas: #{e.message}"
          end

          add_preference_schemas(schemas, Spree::Api::PreferenceFamilies::SELLER)
        end

        # Hand-written shapes the seller branch answers with that no serializer
        # produces — bespoke controller hashes rather than Alba output.
        def seller_common_schemas
          {
            SellerSummary: {
              type: :object,
              description: 'A seller the signed-in user may act for',
              properties: {
                id: { type: :string, description: 'Prefixed seller ID — send as `X-Spree-Seller-Id`', example: 'sel_abc123' },
                name: { type: :string, example: 'Acme Supplies' },
                status: { type: :string, example: 'approved', description: 'Seller lifecycle status' }
              },
              required: %w[id name status]
            },
            SellerMeSummary: {
              type: :object,
              description: 'A seller the signed-in user may act for, as `/me` reports it — the login response carries the same fields without `slug`.',
              properties: {
                id: { type: :string, description: 'Prefixed seller ID — send as `X-Spree-Seller-Id`', example: 'sel_abc123' },
                name: { type: :string, example: 'Acme Supplies' },
                slug: { type: :string, example: 'acme-supplies' },
                status: { type: :string, example: 'approved', description: 'Seller lifecycle status' }
              },
              required: %w[id name slug status]
            },
            SellerMeResponse: {
              type: :object,
              description: 'The signed-in user, the sellers they may act for, and what they may do on the selected one',
              properties: {
                # `Account`, not `TeamMember`: the person reading their own
                # record also sees the panel language they chose, which the
                # team list does not publish about a colleague.
                user: { '$ref' => '#/components/schemas/Account' },
                sellers: { type: :array, items: { '$ref' => '#/components/schemas/SellerMeSummary' } },
                store: { '$ref' => '#/components/schemas/Store' },
                permissions: { type: :array, items: { '$ref' => '#/components/schemas/PermissionRule' } },
                permission_keys: {
                  type: :array,
                  items: { type: :string },
                  description: 'Permission keys on the selected seller. Empty until `X-Spree-Seller-Id` names one — capability is per seller.',
                  example: %w[read_products write_products]
                }
              },
              required: %w[user sellers store permissions permission_keys]
            },
            OnboardingProgress: {
              type: :object,
              description: <<~DESC,
                How far along the checklist is — not how close to approval, since
                optional requirements count towards it too.

                Deliberately just the two counts. A percentage is arithmetic over
                them, which a client can do and which would otherwise be a second
                definition of the same fact.
              DESC
              properties: {
                done: { type: :integer, example: 3 },
                total: { type: :integer, example: 5 }
              },
              required: %w[done total]
            },
            SellerOnboardingResponse: {
              type: :object,
              description: "What the marketplace asks of this seller before it will admit them",
              properties: {
                status: { type: :string, example: 'onboarding', description: "The seller's lifecycle status" },
                progress: { '$ref' => '#/components/schemas/OnboardingProgress' },
                requirements: { type: :array, items: { '$ref' => '#/components/schemas/RequirementStatus' } }
              },
              required: %w[status progress requirements]
            },
            AuthProvidersResponse: {
              type: :object,
              description: 'Sign-in methods this marketplace offers sellers, for the login page',
              properties: {
                providers: {
                  type: :array,
                  items: { type: :object, additionalProperties: true }
                }
              },
              required: %w[providers]
            }
          }
        end

        private

        def typelizer_schemas(writer_name)
          schemas = Typelizer.openapi_schemas(writer_name: writer_name)
          schemas.each_value do |s|
            s[:'x-typelizer'] = true
            strip_null_from_enums(s)
          end
          patch_typescript_only_types(schemas, writer_name)
          patch_promotion_action_calculator(schemas)
          schemas
        end

        # Typelizer publishes a type only TypeScript can express (`Array<{ … }>`,
        # `any`) as a plain object. Give each such property the shape the API
        # sends — an array, or any value — so responses validate against it.
        # A list of objects is better declared as an inline shape
        # (`typelize({ id: :string }, multi: true)`), which documents its fields.
        def patch_typescript_only_types(schemas, writer_name)
          Typelizer.interfaces(writer_name: writer_name).each do |interface|
            properties = (schemas[interface.name] || schemas[interface.name.to_sym])&.dig(:properties)
            next unless properties

            interface.properties.each do |property|
              key = [property.name.to_s, property.name.to_sym].find { |name| properties.key?(name) }
              schema = key && !property.type.is_a?(Array) && typescript_only_type_schema(property.type.to_s)
              next unless schema

              schema[:nullable] = true if property.nullable || property.type.to_s.end_with?('| null')
              properties[key] = schema.merge(properties[key].slice(:description))
            end
          end
        end

        def typescript_only_type_schema(type)
          case type.delete_suffix(' | null')
          when /\AArray<(string|number|boolean)>\z/ then { type: :array, items: { type: Regexp.last_match(1).to_sym } }
          when /\AArray</ then { type: :array, items: { type: :object } }
          when 'any', 'unknown' then {}
          end
        end

        # The calculator's TypeScript type has another name than its component.
        def patch_promotion_action_calculator(schemas)
          action = schemas['PromotionAction'] || schemas[:PromotionAction]
          props = action&.dig(:properties)
          return unless props

          key = props.key?('calculator') ? 'calculator' : :calculator
          props[key] = Typelizer::NullableReferences.wrap(ref('PromotionActionCalculator')) if props[key]
        end

        # One component per subtype Spree ships (`PromotionRuleItemTotalPreferences`)
        # and one per family (`PromotionRulePreferences`) that the family's
        # resource points its `preferences` at. A type an extension registers
        # matches the final plain object; its shape is the `schema` in the
        # family's `/types` response.
        #
        # @param schemas [Hash] components, changed in place
        # @param families [Array<String>]
        # @return [Hash] the components
        def add_preference_schemas(schemas, families)
          Spree::Api::PreferenceFamilies.schemas(families).each do |family, members|
            refs = members.to_h do |type, schema|
              name = Spree::Api::PreferenceFamilies.member_name(family, type)
              schemas[name] = openapi_schema(schema)
              [type, "#/components/schemas/#{name}"]
            end

            schemas["#{family}Preferences"] = {
              description: "Settings of a #{family.titleize.downcase}, shaped by its `type` (see `x-spree-preferences-by-type`). " \
                           'A type an extension registers is a plain object, described by the `schema` its `/types` entry carries.',
              anyOf: refs.values.map { |ref| { '$ref' => ref } } + [{ type: :object, additionalProperties: true }],
              'x-spree-preferences-by-type' => refs
            }

            resource = schemas[family] || schemas[family.to_sym]
            props = resource&.dig(:properties)
            key = props&.key?('preferences') ? 'preferences' : :preferences
            props[key] = { '$ref' => "#/components/schemas/#{family}Preferences" } if props&.key?(key)
          end

          # A calculator names its family's union, so it is published only
          # alongside that union.
          CALCULATOR_SCHEMAS.slice(*families).each_value { |name, schema| schemas[name] = schema }
          patch_delivery_method_calculator(schemas)
          schemas
        end

        # The generated JSON Schema is draft 2020-12; OpenAPI 3.0 spells a
        # nullable type as `nullable: true` and has no `propertyNames`.
        def openapi_schema(schema)
          case schema
          when Hash
            converted = schema.each_with_object({}) do |(key, value), result|
              next if key == 'propertyNames'

              result[key] = %w[enum default required].include?(key) ? value : openapi_schema(value)
            end
            if schema['type'].is_a?(Array)
              converted['type'] = (schema['type'] - ['null']).first
              converted['nullable'] = true if schema['type'].include?('null')
            end
            converted['enum'] = converted['enum'].compact if converted['enum']
            converted['x-spree-property-names'] = openapi_schema(schema['propertyNames']) if schema['propertyNames']
            converted
          when Array then schema.map { |item| openapi_schema(item) }
          else schema
          end
        end

        def patch_delivery_method_calculator(schemas)
          method = schemas['DeliveryMethod'] || schemas[:DeliveryMethod]
          props = method&.dig(:properties)
          return unless props

          key = props.key?('calculator') ? 'calculator' : :calculator
          props[key] = Typelizer::NullableReferences.wrap(ref('DeliveryMethodCalculator')) if props[key]
        end

        # Typelizer adds nil to enum arrays for nullable fields.
        # OpenAPI 3.0 handles nullability via `nullable: true`, so the nil entry is redundant
        # and causes issues with code generators. The array is often a model's
        # frozen constant (`Spree::Fee::KINDS`), so it is replaced, never mutated.
        def strip_null_from_enums(schema)
          properties = schema[:properties] || {}
          properties.each_value do |prop|
            next unless prop.is_a?(Hash) && prop[:enum].is_a?(Array)

            prop[:enum] = prop[:enum].compact
          end
        end
      end
    end
  end
end
