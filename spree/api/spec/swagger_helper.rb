# frozen_string_literal: true

require 'spec_helper'
require 'rswag/specs'

# Load OpenAPI helpers
require 'spree/api/openapi/schema_helper'

RSpec.configure do |config|
  # Output to the main spree docs directory at /docs/api-reference/
  config.openapi_root = Rails.root.join('../../../../docs').to_s

  config.openapi_specs = {
    # Store API v3 - Customer-facing storefront API
    'api-reference/store.yaml' => {
      openapi: '3.0.3',
      info: {
        title: 'Store API',
        contact: {
          name: 'Spree Commerce',
          url: 'https://spreecommerce.org',
          email: 'hello@spreecommerce.org',
        },
        description: <<~DESC,
          Spree Store API v3 - Customer-facing storefront API for building headless commerce experiences.

          ## Authentication

          The Store API uses two authentication methods:

          ### API Key (Required)
          All requests must include a publishable API key in the `x-spree-api-key` header.

          ### JWT Bearer Token (For authenticated customers)
          After login, include the JWT token in the `Authorization: Bearer <token>` header.

          ### Order Token (For guest checkout)
          When creating an order, a `token` is returned. Include this in the `x-spree-token` header
          for guest access to that specific order.

          ## Response Format

          All responses are JSON. List endpoints return paginated responses with `data` and `meta` keys.

          ## Error Handling

          Errors return a consistent format:
          ```json
          {
            "error": {
              "code": "record_not_found",
              "message": "Product not found"
            }
          }
          ```
        DESC
        version: 'v3'
      },
      paths: {},
      servers: [
        {
          url: 'http://{defaultHost}',
          variables: {
            defaultHost: {
              default: 'localhost:3000'
            }
          }
        }
      ],
      tags: [
        { name: 'Authentication', description: 'Customer authentication (login, logout, token refresh)' },
        { name: 'Product Catalog', description: 'Products and categories' },
        { name: 'Carts', description: 'Shopping cart management' },
        { name: 'Orders', description: 'Order lookup' },
        { name: 'Customers', description: 'Customer account, addresses, saved payment methods, and order history' },
        { name: 'Markets', description: 'Markets, countries, currencies, and locales' },
        { name: 'Wishlists', description: 'Customer wishlists' },
        { name: 'Newsletter Subscribers', description: 'Guest and customer newsletter subscriptions (double opt-in)' },
        { name: 'Policies', description: 'Store policies (return policy, privacy policy, terms of service)' },
        { name: 'Digitals', description: 'Digital product downloads' }
      ],
      'x-tagGroups': [
        { name: 'Authentication', tags: ['Authentication'] },
        { name: 'Product Catalog', tags: ['Product Catalog'] },
        { name: 'Carts', tags: ['Carts'] },
        { name: 'Orders', tags: ['Orders'] },
        { name: 'Customers', tags: ['Customers'] },
        { name: 'Markets', tags: ['Markets'] },
        { name: 'Wishlists', tags: ['Wishlists'] },
        { name: 'Newsletter Subscribers', tags: ['Newsletter Subscribers'] },
        { name: 'Policies', tags: ['Policies'] },
        { name: 'Digitals', tags: ['Digitals'] }
      ],
      components: {
        securitySchemes: {
          api_key: {
            type: :apiKey,
            name: 'x-spree-api-key',
            in: :header,
            description: 'Publishable API key for store access'
          },
          bearer_auth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: 'JWT',
            description: 'JWT token for authenticated customers'
          }
        },
        schemas: Spree::Api::OpenAPI::SchemaHelper.all_schemas
      }
    },

    # Admin API v3 - Administrative API for managing store resources
    'api-reference/admin.yaml' => {
      openapi: '3.0.3',
      info: {
        title: 'Admin API',
        contact: {
          name: 'Spree Commerce',
          url: 'https://spreecommerce.org',
          email: 'hello@spreecommerce.org',
        },
        description: <<~DESC,
          Spree Admin API v3 - Administrative API for managing products, orders, and store settings.

          ## Authentication

          The Admin API requires a secret API key passed in the `x-spree-api-key` header.
          Secret API keys can be generated in the Spree admin dashboard.

          ## Response Format

          All responses are JSON. List endpoints return paginated responses with `data` and `meta` keys.
          Single resource endpoints return a flat JSON object.

          ## Resource IDs

          Every resource is identified by an opaque string ID (e.g. `prod_86Rf07xd4z`,
          `variant_k5nR8xLq`, `or_UkLWZg9DAJ`). Use these IDs everywhere — URL paths,
          request bodies, and Ransack filters all accept them directly.

          ## Error Handling

          Errors return a consistent format:
          ```json
          {
            "error": {
              "code": "validation_error",
              "message": "Validation failed",
              "details": { "name": ["can't be blank"] }
            }
          }
          ```
        DESC
        version: 'v3'
      },
      paths: {},
      servers: [
        {
          url: 'http://{defaultHost}',
          variables: {
            defaultHost: {
              default: 'localhost:3000'
            }
          }
        }
      ],
      tags: [
        { name: 'Authentication', description: 'Admin user authentication' },
        { name: 'Product Catalog', description: 'Products, variants, and option types' },
        { name: 'Orders', description: 'Order management — orders, items, payments, fulfillments, refunds, gift cards, store credits' },
        { name: 'Customers', description: 'Customer management — profiles, addresses, store credits, credit cards' },
        { name: 'Configuration', description: 'Store configuration — payment methods, tag autocomplete' }
      ],
      'x-tagGroups': [
        { name: 'Authentication', tags: ['Authentication'] },
        { name: 'Product Catalog', tags: ['Product Catalog'] },
        { name: 'Orders', tags: ['Orders'] },
        { name: 'Customers', tags: ['Customers'] },
        { name: 'Configuration', tags: ['Configuration'] }
      ],
      components: {
        securitySchemes: {
          api_key: {
            type: :apiKey,
            name: 'x-spree-api-key',
            in: :header,
            description: 'Secret API key for admin access'
          },
          bearer_auth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: 'JWT',
            description: 'JWT token for admin user authentication'
          }
        },
        schemas: Spree::Api::OpenAPI::SchemaHelper.admin_schemas
      }
    }
  }

  config.openapi_format = :yaml

  # Auto-generate examples from actual test responses
  # This captures real response data and embeds it in the OpenAPI spec
  # Note: We need to modify the example_group's metadata, not the example's,
  # because rswag reads from example_group.metadata in example_group_finished
  config.after(:each, type: :request) do |example|
    # Only process request specs with response metadata (rswag integration tests)
    response_metadata = example.metadata[:response]
    next unless response_metadata
    next unless respond_to?(:response) && response.present? && response.body.present?

    begin
      content = response_metadata[:content] ||= {}
      content['application/json'] ||= {}
      content['application/json'][:example] = JSON.parse(response.body, symbolize_names: true)
    rescue JSON::ParserError
      # Skip if response body is not valid JSON
    end
  end
end

# Helper module for use in specs
module SwaggerSchemaHelpers
  extend Spree::Api::OpenAPI::SchemaHelper
end
