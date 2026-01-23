# Spree API

[![Gem Version](https://badge.fury.io/rb/spree_api.svg)](https://badge.fury.io/rb/spree_api)

Spree API provides RESTful API endpoints for building custom storefronts, mobile applications, and third-party integrations with Spree Commerce.

## Overview

This gem includes:

- **Storefront API** - Customer-facing endpoints for cart, checkout, products, and accounts
- **Platform API** - Administrative endpoints for managing orders, products, and store settings
- **Webhooks** - Event-driven notifications to external systems
- **OAuth2 Authentication** - Token-based authentication via Doorkeeper
- **JSONAPI Serializers** - Standardized API responses

## Installation

This gem is included in every Spree installation. No additional steps are required.

## API Endpoints

### Storefront API (v2)

The Storefront API is designed for building custom frontends:

```
GET    /api/v2/storefront/products
GET    /api/v2/storefront/products/:id
GET    /api/v2/storefront/taxons
POST   /api/v2/storefront/cart
PATCH  /api/v2/storefront/cart/add_item
PATCH  /api/v2/storefront/checkout
POST   /api/v2/storefront/account
```

### Platform API

The Platform API provides administrative access:

```
GET    /api/v2/platform/orders
POST   /api/v2/platform/products
PATCH  /api/v2/platform/variants/:id
DELETE /api/v2/platform/line_items/:id
```

## Authentication

### OAuth2 Token Authentication

```bash
# Request access token
curl -X POST https://your-store.com/spree_oauth/token \
  -d "grant_type=password&username=user@example.com&password=secret"

# Use token in requests
curl -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  https://your-store.com/api/v2/storefront/account
```

### Guest Cart Token

For guest checkout, use the `X-Spree-Order-Token` header:

```bash
curl -H "X-Spree-Order-Token: ORDER_TOKEN" \
  https://your-store.com/api/v2/storefront/cart
```

## Serializers

API responses use JSONAPI format. Customize serializers by creating your own:

```ruby
# app/serializers/my_app/product_serializer.rb
module MyApp
  class ProductSerializer < Spree::V2::Storefront::ProductSerializer
    attribute :custom_field
  end
end

# Configure in initializer
Spree.api.storefront_product_serializer = 'MyApp::ProductSerializer'
```

## Testing

```bash
cd api
bundle exec rake test_app  # First time only
bundle exec rspec
```

## Documentation

- [Storefront API Reference](https://docs.spreecommerce.org/api/storefront)
- [Platform API Reference](https://docs.spreecommerce.org/api/platform)
- [Authentication Guide](https://docs.spreecommerce.org/developer/api/authentication)