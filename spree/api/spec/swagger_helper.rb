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
      # Authentication first, the rest alphabetical — Mintlify renders one
      # sidebar group per tag in this order, and any operation tag missing
      # from this list gets appended at the bottom of the sidebar. Keep every
      # operation tag listed.
      tags: [
        { name: 'Authentication', description: 'Admin user login, logout, token refresh, and current user profile' },
        { name: 'Allowed Origins', description: 'CORS allowlist for storefront and admin client origins' },
        { name: 'API Keys', description: 'Secret and publishable API keys' },
        { name: 'Categories', description: 'Hierarchical product categories — tree management, repositioning, and product assignments' },
        { name: 'Channels', description: 'Sales channels, product publication across channels, and per-channel order routing rules' },
        { name: 'Custom Fields', description: 'Custom field definitions for products, variants, customers, and other resources' },
        { name: 'Customer Groups', description: 'Customer groups for segmenting customers (e.g. wholesale, VIP) used by pricing and promotions' },
        { name: 'Customers', description: 'Customer profiles, addresses, credit cards, and store credits' },
        { name: 'Exports', description: 'Async CSV exports of admin resources' },
        { name: 'Fulfillments', description: 'Order fulfillments — shipments, fulfill, cancel, resume, split' },
        { name: 'Gift Cards', description: 'Gift cards and gift card batches' },
        { name: 'Imports', description: 'Async CSV imports of admin resources, with per-row status and failed-row retry' },
        { name: 'Markets', description: 'Markets — geographic groupings of countries used for pricing, tax, and fulfillment rules' },
        { name: 'Option Types', description: 'Option types and option values used to build product variants (e.g. Size, Color)' },
        { name: 'Orders', description: 'Orders, order items, applied gift cards, and applied store credits' },
        { name: 'Payment Methods', description: 'Configured payment providers and their available types' },
        { name: 'Payments', description: 'Order payments — list, capture, void' },
        { name: 'Pricing', description: 'Prices and price lists for currency-, market-, and customer-group-specific pricing' },
        { name: 'Products', description: 'Products, taxons/categories, product custom field values, and bulk product operations' },
        { name: 'Policies', description: "The store's legal documents — terms of service, privacy, returns, shipping" },
        { name: 'Promotions', description: 'Promotions, promotion rules, promotion actions, and coupon codes' },
        { name: 'Refunds', description: 'Order refunds' },
        { name: 'Settings', description: 'Store-level settings — store profile, tags, store credit categories' },
        { name: 'Staff', description: 'Admin users, roles, and invitations to the store' },
        { name: 'Stock Locations', description: 'Warehouses and physical fulfillment locations' },
        { name: 'Variants', description: 'Product variants — the individual SKUs (size/color combinations) sold under a product' },
        { name: 'Webhooks', description: 'Webhook endpoints and webhook delivery history' }
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
    },

    # Seller API v3 - The marketplace seller panel
    'api-reference/seller.yaml' => {
      openapi: '3.0.3',
      info: {
        title: 'Seller API',
        contact: {
          name: 'Spree Commerce',
          url: 'https://spreecommerce.org',
          email: 'hello@spreecommerce.org',
        },
        description: <<~DESC,
          Spree Seller API v3 - the marketplace seller panel, where a seller runs
          their own shop inside someone else's marketplace.

          This is a branch of its own, not a narrowing of the Admin API. Every
          endpoint is scoped server-side to the seller the request acts as, which
          is what makes cross-seller access impossible by construction rather
          than by rule. Sellers never call the Admin API.

          ## Authentication

          Sign in at `POST /api/v3/seller/auth/login` and send the returned JWT as
          `Authorization: Bearer <token>`. The token carries a `seller_api`
          audience — a token minted for the storefront or the back office is not
          accepted here, and vice versa.

          There is deliberately **no secret API key** for this branch: a
          credential that could act as a seller without a seller signing in is
          exactly what the separate audience exists to prevent.

          ### Choosing a seller

          A user may run more than one seller. Login returns the list; send the
          chosen seller's ID in the `X-Spree-Seller-Id` header on every
          authenticated request. The store is derived from the seller — never
          sent — so no header can widen what a seller reaches. A request that
          names no seller the caller belongs to is rejected with `403`.

          ## Response Format

          All responses are JSON. List endpoints return paginated responses with
          `data` and `meta` keys.

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
      # Authentication first, the rest alphabetical — see the Admin API's
      # note above: Mintlify renders one sidebar group per tag in this
      # order, so every operation tag must be listed here.
      tags: [
        { name: 'Authentication', description: 'Seller sign-in, token refresh, logout, and invitation acceptance' },
        { name: 'Account', description: 'The signed-in user, the sellers they may act for, and what they may do' },
        { name: 'Countries', description: 'Country and state reference data for the panel\'s address forms' },
        { name: 'Onboarding', description: 'The marketplace checklist a seller completes before admission, and what they submit against it' },
        { name: 'Policies', description: "The seller's own legal documents, as the marketplace asks them to publish" },
        { name: 'Products', description: "The seller's own catalog" },
        { name: 'Profile', description: "The seller's own record — presentation, contact details, addresses, and tax registration" },
        { name: 'Stock Locations', description: 'Where the seller keeps stock, and so where their returns are sent' },
        { name: 'Team', description: 'Who runs this seller, and the invitations nobody has accepted yet' },
        { name: 'Uploads', description: 'Presigned direct uploads for the documents onboarding asks for' }
      ],
      components: {
        securitySchemes: {
          bearer_auth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: 'JWT',
            description: 'JWT token for an authenticated seller session (`seller_api` audience)'
          }
        },
        schemas: Spree::Api::OpenAPI::SchemaHelper.seller_schemas
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
