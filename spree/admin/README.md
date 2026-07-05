# Spree Admin

[![Gem Version](https://badge.fury.io/rb/spree_admin.svg)](https://badge.fury.io/rb/spree_admin)

Spree Admin provides a modern, fully-featured admin dashboard for managing your Spree application.

## Overview

This gem includes:

- **Dashboard** - Analytics and KPI overview
- **Product Management** - Products, variants, properties, option types
- **Order Management** - Orders, payments, shipments, refunds
- **Customer Management** - Customer accounts and order history
- **Inventory Management** - Stock locations, stock items, transfers
- **Promotions** - Discounts, coupon codes, promotion rules
- **Content Management** - Pages, menus, navigation
- **Settings** - Store configuration, payment methods, shipping methods, taxes

## Installation

```bash
bundle add spree_admin
bin/rails g spree:admin:install
```

You will need to restart your web server and run `bin/dev` to start the development server for the admin dashboard.

## Features

### Dynamic Tables

Register customizable tables for your resources:

```ruby
# config/initializers/spree_admin_tables.rb
Rails.application.config.after_initialize do
  Spree.admin.tables.register(:gift_cards, model_class: Spree::GiftCard)

  Spree.admin.tables.gift_cards.add :code,
    label: :code,
    type: :string,
    sortable: true,
    filterable: true,
    default: true,
    position: 10
end
```

Column types: `:string`, `:currency`, `:date`, `:datetime`, `:boolean`, `:custom`

### Navigation

Configure sidebar and settings navigation:

```ruby
# config/initializers/spree_admin_navigation.rb
Rails.application.config.after_initialize do
  Spree.admin.navigation.sidebar.add :reports,
    label: :reports,
    url: :admin_reports_path,
    icon: 'chart-bar',
    position: 60,
    if: -> { can?(:manage, Spree::Report) }
end
```

### Partial Hooks

Extend the admin interface with partial hooks (100+ available):

```erb
<%# app/views/spree/admin/orders/_show_sidebar.html.erb %>
<div class="card">
  <div class="card-body">
    Custom order sidebar content
  </div>
</div>
```

### Controllers

Admin controllers inherit from `Spree::Admin::ResourceController` for consistent CRUD:

```ruby
module Spree
  module Admin
    class GiftCardsController < ResourceController
      private

      def model_class
        Spree::GiftCard
      end

      def permitted_resource_params
        params.require(:gift_card).permit(
          Spree::PermittedAttributes.gift_card_attributes
        )
      end
    end
  end
end
```

### Form Builder

Use the Spree admin form builder for consistent styling:

```erb
<%= f.spree_text_field :name %>
<%= f.spree_text_area :description %>
<%= f.spree_check_box :active %>
<%= f.spree_select :status, options_for_status %>
```

## Technology Stack

- **Tailwind CSS** - Utility-first CSS framework
- **Turbo/Hotwire** - SPA-like interactions without JavaScript frameworks
- **Stimulus** - Modest JavaScript framework for controllers

## Testing

```bash
cd admin
bundle exec rake test_app  # First time only
bundle exec rspec
```

For controller specs, use `stub_authorization!` for authentication:

```ruby
RSpec.describe Spree::Admin::ProductsController, type: :controller do
  stub_authorization!
  render_views

  describe 'GET #index' do
    it 'renders the index template' do
      get :index
      expect(response).to render_template(:index)
    end
  end
end
```

## Documentation

- [Admin Customization Guide](https://docs.spreecommerce.org/developer/customization/admin)
- [Navigation Configuration](https://docs.spreecommerce.org/developer/customization/admin-navigation)
- [Permissions Guide](https://docs.spreecommerce.org/developer/customization/permissions)
