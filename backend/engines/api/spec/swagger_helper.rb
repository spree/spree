# frozen_string_literal: true

require 'spec_helper'
require 'rswag/specs'

# Load OpenAPI helpers
require 'spree/api/openapi/schema_helper'

RSpec.configure do |config|
  # Output to the main spree docs directory at /docs/api-reference/
  config.openapi_root = Rails.root.join('../../../../../docs').to_s

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
          When creating an order, an `order_token` is returned. Include this as a query parameter
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
        { name: 'Authentication', description: 'Customer authentication and registration' },
        { name: 'Store', description: 'Store information and settings' },
        { name: 'Product Catalog', description: 'Products, taxonomies, and categories' },
        { name: 'Internationalization', description: 'Countries, currencies, and locales available in the store' },
        { name: 'Cart', description: 'Shopping cart management' },
        { name: 'Checkout', description: 'Checkout flow and order updates' },
        { name: 'Orders', description: 'Order lookup' },
        { name: 'Customers', description: 'Customer account, addresses, saved payment methods, and order history' },
        { name: 'Wishlists', description: 'Customer wishlists' },
        { name: 'Digitals', description: 'Digital product downloads' }
      ],
      'x-tagGroups': [
        { name: 'Store', tags: %w[Store Internationalization] },
        { name: 'Catalog', tags: ['Product Catalog'] },
        { name: 'Cart', tags: ['Cart'] },
        { name: 'Checkout', tags: ['Checkout'] },
        { name: 'Orders', tags: ['Orders'] },
        { name: 'Customer', tags: %w[Authentication Customers Wishlists Digitals] }
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
