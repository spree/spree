# Spree Legacy API v2

> **⚠️ DEPRECATED**: This gem provides the legacy API v2 endpoints for Spree Commerce. It is deprecated and will be removed in a future version. Please migrate to **API v3**.

## Overview

This gem contains the legacy Storefront API v2 and Platform API v2 endpoints that were previously part of `spree_api`. These APIs are now deprecated in favor of the new API v3, which uses Alba serializers and provides a cleaner, more maintainable codebase.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'spree_legacy_api_v2'
```

And run the following command:

```bash
bundle exec rake spree_legacy_api_v2:install
```

This will install the database migrations and run them.

## Migration Guide

### Storefront API

The new Store API v3 provides similar functionality with improved consistency:

| Legacy v2 Endpoint | New v3 Endpoint |
|-------------------|-----------------|
| `GET /api/v2/storefront/products` | `GET /api/v3/store/products` |
| `GET /api/v2/storefront/cart` | `GET /api/v3/store/orders/:id` |
| `POST /api/v2/storefront/cart/add_item` | `POST /api/v3/store/orders/:id/line_items` |
| `GET /api/v2/storefront/account` | `GET /api/v3/store/customers/me` |

### Key Differences

1. **Serialization**: API v3 uses Alba serializers (faster, simpler) instead of JSONAPI::Serializer
2. **Response Format**: API v3 returns simple JSON objects instead of JSONAPI format
3. **Authentication**: Both APIs support the same authentication mechanisms
4. **TypeScript Types**: API v3 automatically generates TypeScript types via Typelizer

## Deprecation Timeline

- **Current**: API v2 is deprecated but fully functional
- **Next Major Release**: API v2 will be removed

## License

Spree is released under the [AGPL-3.0-or-later](https://www.gnu.org/licenses/agpl-3.0.html) and [BSD-3-Clause](https://opensource.org/licenses/BSD-3-Clause) licenses.
