# frozen_string_literal: true

require 'spec_helper'
require 'rswag/specs'

# Load OpenAPI helpers
require 'spree/api/openapi/typelizer_converter'
require 'spree/api/openapi/schema_helper'

RSpec.configure do |config|
  # Output to the main spree docs directory at /docs/api-reference/
  config.openapi_root = Rails.root.join('../../../docs').to_s

  # Helper to generate schemas from Typelizer at spec run time
  def self.store_api_schemas
    schemas = Spree::Api::OpenAPI::SchemaHelper.common_schemas

    # Try to load Typelizer-generated schemas
    begin
      schemas.merge!(Spree::Api::OpenAPI::TypelizerConverter.generate_schemas)
    rescue StandardError => e
      warn "Warning: Could not load Typelizer schemas: #{e.message}"
    end

    schemas
  end

  config.openapi_specs = {
    # Store API v3 - Customer-facing storefront API
    'api-reference/store.yaml' => {
      openapi: '3.0.3',
      info: {
        title: 'Store API',
        contact: {
          name: 'Vendo Connect Inc.',
          url: 'https://getvendo.com',
          email: 'sales@getvendo.com',
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
        { name: 'Products', description: 'Product catalog browsing' },
        { name: 'Taxonomies', description: 'Category hierarchies' },
        { name: 'Taxons', description: 'Individual categories' },
        { name: 'Countries', description: 'Available shipping countries' },
        { name: 'States', description: 'States and provinces' },
        { name: 'Orders', description: 'Shopping cart and checkout' },
        { name: 'Line Items', description: 'Cart item management' },
        { name: 'Payments', description: 'Payment processing' },
        { name: 'Payment Methods', description: 'Available payment options' },
        { name: 'Shipments', description: 'Shipping and delivery' },
        { name: 'Customers', description: 'Customer account management' },
        { name: 'Addresses', description: 'Customer address book' },
        { name: 'Credit Cards', description: 'Saved payment methods' },
        { name: 'Wishlists', description: 'Customer wishlists' },
        { name: 'Digitals', description: 'Digital product downloads' }
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
        schemas: store_api_schemas
      }
    }
  }

  config.openapi_format = :yaml

  # Auto-generate examples from responses
  config.after do |example|
    next if example.metadata[:swagger].nil?
    next if response.nil? || response.body.blank?

    schema_ref = example.metadata.dig(:response, :schema, '$ref')
    next unless schema_ref

    example.metadata[:response][:content] = {
      'application/json' => {
        examples: {
          'Example': {
            value: JSON.parse(response.body, symbolize_names: true)
          }
        },
        schema: { '$ref': schema_ref }
      }
    }
  end
end

# Helper module for use in specs
module SwaggerSchemaHelpers
  extend Spree::Api::OpenAPI::SchemaHelper
end
