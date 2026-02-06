# Spree API

[![Gem Version](https://badge.fury.io/rb/spree_api.svg)](https://badge.fury.io/rb/spree_api)

Spree API provides RESTful API endpoints for building custom storefronts, mobile applications, and third-party integrations with Spree Commerce.

## Overview

This gem includes:

- **Store API v3** - Customer-facing endpoints for cart, checkout, products, and accounts
- **Admin API v3** - Administrative endpoints for managing orders, products, and store settings
- **Webhooks** - Event-driven notifications to external systems
- **API Key Authentication** - Secure token-based authentication with scopes
- **Alba Serializers** - Fast, flexible JSON serialization with TypeScript type generation

## Installation

This gem is included in every Spree installation. No additional steps are required.

## API v3 Endpoints

### Store API

The Store API is designed for building custom storefronts:

```
GET    /api/v3/products
GET    /api/v3/products/:id
GET    /api/v3/taxons
GET    /api/v3/taxonomies
POST   /api/v3/cart
PATCH  /api/v3/cart/add_item
PATCH  /api/v3/checkout
GET    /api/v3/account
```

### Admin API

The Admin API provides full administrative access:

```
GET    /api/v3/admin/orders
POST   /api/v3/admin/products
PATCH  /api/v3/admin/variants/:id
DELETE /api/v3/admin/line_items/:id
```

## Authentication

### API Key Authentication

Create API keys with appropriate scopes:

```ruby
# Store API key (customer-facing)
api_key = Spree::ApiKey.create!(
  name: 'My Storefront',
  scope: 'store',
  store: current_store
)

# Admin API key (full access)
admin_key = Spree::ApiKey.create!(
  name: 'Admin Integration',
  scope: 'admin',
  store: current_store
)
```

Use the API key in requests:

```bash
# Store API
curl -H "Authorization: Bearer spree_pk_xxx" \
  https://your-store.com/api/v3/products

# Admin API
curl -H "Authorization: Bearer spree_sk_xxx" \
  https://your-store.com/api/v3/admin/orders
```

### Guest Cart Token

For guest checkout, use the `X-Spree-Order-Token` header:

```bash
curl -H "X-Spree-Order-Token: ORDER_TOKEN" \
  https://your-store.com/api/v3/cart
```

## Serializers

API v3 uses Alba serializers for fast JSON serialization. Serializers are organized by scope:

- `app/serializers/spree/api/v3/` - Store API serializers
- `app/serializers/spree/api/v3/admin/` - Admin API serializers

Customize serializers by creating your own:

```ruby
# app/serializers/my_app/product_serializer.rb
module MyApp
  class ProductSerializer < Spree::Api::V3::ProductSerializer
    attribute :custom_field
  end
end

# Configure in initializer
Spree.api.product_serializer = 'MyApp::ProductSerializer'
```

## TypeScript Types

TypeScript types are automatically generated from serializers using [typelizer](https://github.com/skryukov/typelizer):

```bash
# Generate TypeScript types
bundle exec rake typelizer:generate
```

Types are output to `sdk/src/types/generated/` with naming:
- Store types: `StoreProduct`, `StoreOrder`, etc.
- Admin types: `AdminProduct`, `AdminOrder`, etc.

## Testing

```bash
cd api
bundle exec rake test_app  # First time only
bundle exec rspec
```

## Documentation

- [API Reference](https://docs.spreecommerce.org/api)
- [Authentication Guide](https://docs.spreecommerce.org/developer/api/authentication)