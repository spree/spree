# Spree Sample

[![Gem Version](https://badge.fury.io/rb/spree_sample.svg)](https://badge.fury.io/rb/spree_sample)

Spree Sample provides sample data for quickly populating a Spree Commerce store with products, categories, and other content for development and demonstration purposes.

## Overview

This gem includes:

- **Sample Products** - Demo products with images, variants, and pricing
- **Taxonomies & Taxons** - Product categories and navigation
- **Stores** - Default store configuration
- **Shipping & Payment** - Pre-configured shipping and payment methods
- **Stock** - Inventory data for sample products
- **Assets** - Product images and other media

## Installation

```bash
bundle add spree_sample
```

## Loading Sample Data

```bash
bin/rails spree_sample:load
```

## Sample Data Contents

### Products

- Multiple product types (apparel, accessories, etc.)
- Product variants with options (size, color)
- Product images
- Pricing information
- Stock quantities

### Taxonomies

- Categories taxonomy
- Brand taxonomy
- Sample taxons with product associations

### Store Configuration

- Default store settings
- Currency and locale
- SEO defaults

### Shipping

- Shipping categories
- Shipping methods with zones
- Calculator configurations

### Payment

- Payment methods
- Test payment gateway

## Customization

### Loading Specific Samples

Load only the data you need:

```ruby
require 'spree/sample'

# Load specific samples
Spree::Sample.load_sample('stores')
Spree::Sample.load_sample('taxonomies')
Spree::Sample.load_sample('products')
Spree::Sample.load_sample('variants')
```

### Custom Sample Data

Create your own sample data files:

```ruby
# db/samples/my_custom_data.rb
Spree::Product.find_or_create_by!(name: 'Custom Product') do |product|
  product.price = 29.99
  product.shipping_category = Spree::ShippingCategory.first
end
```

Load custom samples:

```ruby
load Rails.root.join('db/samples/my_custom_data.rb')
```

### Sample Data Structure

```
sample/
├── db/
│   ├── samples/
│   │   ├── stores.rb
│   │   ├── tax_categories.rb
│   │   ├── shipping_categories.rb
│   │   ├── taxonomies.rb
│   │   ├── products.rb
│   │   ├── variants.rb
│   │   ├── option_types.rb
│   │   ├── option_values.rb
│   │   ├── images/
│   │   └── ...
│   └── seeds.rb
└── lib/
    ├── spree_sample.rb
    └── tasks/
        └── sample.rake
```

## Dependencies

- **FFaker** - Used for generating realistic fake data

## Development Use Cases

- **Local Development** - Quick store setup for testing features
- **Demos** - Showcase Spree capabilities to stakeholders
- **CI/CD** - Consistent test data for automated testing
- **Training** - Learning environment with realistic data

## Clearing Sample Data

To reset and reload sample data:

```ruby
# Clear existing data (be careful in production!)
Spree::Product.destroy_all
Spree::Taxon.destroy_all

# Reload samples
bin/rails spree_sample:load
```

## Testing

```bash
cd sample
bundle exec rake test_app  # First time only
bundle exec rspec
```

## Documentation

- [Installation Guide](https://docs.spreecommerce.org/developer/getting-started/installation)
- [Sample Data Reference](https://docs.spreecommerce.org/developer/getting-started/sample-data)