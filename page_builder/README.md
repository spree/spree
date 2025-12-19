# Spree Page Builder

Visual page builder and theme management for Spree Commerce storefronts.

## Overview

Spree Page Builder provides a visual drag-and-drop interface for building and customizing storefront pages. It includes:

- **Theme Management**: Create and manage multiple themes for your store
- **Page Builder**: Visual editor for creating custom pages
- **Page Sections**: Pre-built section components (headers, footers, product grids, etc.)
- **Page Blocks**: Content blocks within sections (text, images, buttons, etc.)

## Installation

Add this line to your Spree application's Gemfile:

```ruby
gem 'spree_page_builder'
```

Or install it through the storefront gem (recommended):

```ruby
gem 'spree_storefront'
```

Then execute:

```bash
bundle install
rails spree_page_builder:install:migrations
rails db:migrate
```

## Dependencies

- `spree_core` - Core Spree functionality
- `spree_admin` - Admin dashboard for managing pages and themes

## License

Spree Page Builder is released under the [AGPL-3.0-or-later License](LICENSE.md).
