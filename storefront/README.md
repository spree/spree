# Spree Storefront

[![Gem Version](https://badge.fury.io/rb/spree_storefront.svg)](https://badge.fury.io/rb/spree_storefront)

Spree Storefront provides a modern, fully-featured Rails-based storefront for Spree Commerce with a responsive design and optimized shopping experience.

## Overview

This gem includes:

- **Product Catalog** - Browsing, filtering, and search
- **Shopping Cart** - Full cart management with guest and authenticated checkout
- **Checkout Flow** - Multi-step checkout with address, shipping, and payment
- **Customer Accounts** - Registration, login, order history, wishlists
- **Page Builder Integration** - Custom landing pages and content
- **SEO Optimization** - Meta tags, structured data, and sitemap support

## Installation

```bash
bundle add spree_storefront
bin/rails g spree:storefront:install
```

## Features

### Product Catalog

- Product listing with pagination
- Category and taxonomy navigation
- Faceted search and filtering
- Product variants and options
- Image galleries
- Related products

### Shopping Cart

- Add/remove items
- Update quantities
- Apply coupon codes
- Guest cart persistence
- Cart merge on login

### Checkout

- Address management (billing/shipping)
- Shipping method selection
- Payment processing
- Order review and confirmation
- Guest checkout support

### Customer Accounts

- Registration and authentication
- Order history
- Address book
- Wishlists
- Account settings

## Technology Stack

- **Tailwind CSS** - Responsive, mobile-first design
- **Turbo/Hotwire** - Fast, SPA-like navigation
- **Stimulus** - JavaScript controllers for interactivity
- **Heroicons** - Icon library

## Customization

### Overriding Views

Copy views to customize the storefront appearance:

```bash
# Copy all storefront views
cp -r $(bundle show spree_storefront)/app/views/spree app/views/

# Or copy specific templates
cp $(bundle show spree_storefront)/app/views/spree/products/show.html.erb \
   app/views/spree/products/
```

### Styling

Customize Tailwind configuration:

```javascript
// tailwind.config.js
module.exports = {
  content: [
    // Include Spree Storefront views
    `${process.env.GEM_HOME}/gems/spree_storefront-*/app/views/**/*.erb`,
    './app/views/**/*.erb',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js'
  ],
  theme: {
    extend: {
      colors: {
        primary: '#your-brand-color'
      }
    }
  }
}
```

### Controllers

Extend storefront controllers for custom behavior:

```ruby
# app/controllers/spree/products_controller_decorator.rb
module Spree
  module ProductsControllerDecorator
    def show
      super
      @related_products = @product.related_products.limit(4)
    end
  end
end

Spree::ProductsController.prepend(Spree::ProductsControllerDecorator)
```

### Helpers

Add custom helpers for view logic:

```ruby
# app/helpers/spree/products_helper_decorator.rb
module Spree
  module ProductsHelperDecorator
    def product_badge(product)
      return unless product.on_sale?
      content_tag(:span, 'Sale', class: 'badge badge-sale')
    end
  end
end

Spree::ProductsHelper.prepend(Spree::ProductsHelperDecorator)
```

## Routes

Storefront routes are mounted automatically. Customize in your routes file:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Custom routes before Spree
  get '/shop', to: redirect('/products')

  # Spree routes
  mount Spree::Core::Engine, at: '/'
end
```

## Testing

```bash
cd storefront
bundle exec rake test_app  # First time only
bundle exec rspec
```

## Page Builder Integration

The storefront integrates with Spree Page Builder for custom pages:

```ruby
# Custom page sections are automatically rendered
# Configure in admin under Content > Pages
```

## Documentation

- [Storefront Customization](https://docs.spreecommerce.org/developer/customization/storefront)
- [Theming Guide](https://docs.spreecommerce.org/developer/customization/theming)
- [Page Builder](https://docs.spreecommerce.org/developer/page-builder)

## Headless Alternative

For custom frontends (React, Vue, Next.js), use `spree_api` without `spree_storefront`:

```ruby
# Headless setup
gem 'spree'        # Core + API
gem 'spree_admin'  # Admin dashboard only
```