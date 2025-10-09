# Claude Code Rules for Spree Commerce Development

## General Development Guidelines

### Framework & Architecture
- Spree is built on **Ruby on Rails** and follows **MVC architecture**.
- All Spree code must be namespaced under `Spree::`.
- Spree is distributed as Rails engines with separate gems (core, admin, api, storefront, emails, etc.).
- Follow Rails conventions and the [Rails Security Guide](https://guides.rubyonrails.org/security.html).
- Prefer Rails idioms and standard patterns over custom solutions.

### Code Organization
- Models → `app/models/spree/`
- Controllers → `app/controllers/spree/`
- Views → `app/views/spree/`
- Services → `app/services/spree/`
- Mailers → `app/mailers/spree/`
- API Serializers → `app/serializers/spree/`
- Helpers → `app/helpers/spree/`
- Jobs → `app/jobs/spree/`
- Presenters → `app/presenters/spree/`
- Use consistent file naming: `spree/product.rb` for `Spree::Product`.
- Group related functionality into **concerns** when appropriate.
- Use `Spree.user_class` instead of calling `Spree::User` directly.
- Use `Spree.admin_user_class` instead of calling `Spree::AdminUser` directly.

---

## Naming Conventions & Structure

### Classes & Modules

```ruby
# ✅ Correct
module Spree
  class Product < Spree.base_class
  end
end

module Spree
  module Admin
    class ProductsController < ResourceController
    end
  end
end

# ❌ Incorrect
class Product < ApplicationRecord
end

