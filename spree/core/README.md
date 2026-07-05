# Spree Core

[![Gem Version](https://badge.fury.io/rb/spree_core.svg)](https://badge.fury.io/rb/spree_core)

Spree Core is the foundation of Spree Commerce, containing all the essential models, services, and business logic that power an e-commerce application.

## Overview

This gem provides:

- **Domain Models** - Products, Variants, Orders, Payments, Shipments, Taxons, Stores, and more
- **Services** - Cart operations, checkout flows, order management, inventory handling
- **State Machines** - Order and payment state management
- **Events System** - Publish/subscribe architecture for loose coupling
- **Dependencies Injection** - Swappable service implementations via `Spree::Dependencies`
- **Permissions** - CanCanCan-based authorization with Permission Sets

## Installation

This gem is included in every Spree installation. No additional steps are required.

## Key Components

### Models

All models are namespaced under `Spree::` and include:

- `Spree::Product` / `Spree::Variant` - Product catalog
- `Spree::Order` / `Spree::LineItem` - Order management
- `Spree::Payment` / `Spree::PaymentMethod` - Payment processing
- `Spree::Shipment` / `Spree::ShippingMethod` - Shipping and fulfillment
- `Spree::Taxon` / `Spree::Taxonomy` - Product categorization
- `Spree::Store` - Multi-store support
- `Spree::Promotion` - Promotions and discounts
- `Spree::GiftCard` - Gift card functionality

### Services

Services follow a consistent interface pattern and are located in `app/services/spree/`:

```ruby
# Add item to cart
Spree.cart_add_item_service.call(
  order: order,
  variant: variant,
  quantity: 1
)
```

### Events System

Spree uses an event-driven architecture for decoupling components:

```ruby
# Publishing events
order.publish_event('order.completed')

# Subscribing to events
module Spree
  module MySubscriber
    include Spree::Event::Subscriber

    event_action :order_completed

    def order_completed(event)
      order = event.payload[:order]
      # Handle the event
    end
  end
end
```

### Dependencies

Swap out default implementations with custom services:

```ruby
# config/initializers/spree.rb
Spree::Dependencies.cart_add_item_service = 'MyCustom::CartAddItem'
```

## Configuration

Configure Spree in an initializer:

```ruby
# config/initializers/spree.rb
Spree.config do |config|
  config.currency = 'USD'
  config.default_country_iso = 'US'
end
```

## Testing

Spree Core includes testing support utilities:

```ruby
# spec/rails_helper.rb
require 'spree/testing_support/factories'
require 'spree/testing_support/authorization_helpers'
```

To run the test suite:

```bash
cd core
bundle exec rake test_app  # First time only
bundle exec rspec
```

## Documentation

- [Official Documentation](https://docs.spreecommerce.org)
- [API Reference](https://api.spreecommerce.org)
- [Guides](https://docs.spreecommerce.org/developer)