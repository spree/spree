# Spree CLI

[![Gem Version](https://badge.fury.io/rb/spree_cli.svg)](https://badge.fury.io/rb/spree_cli)

Spree CLI is a command-line tool for Spree Commerce developers, providing generators and utilities for creating Spree extensions and managing Spree projects.

## Installation

This gem is included in every Spree installation.

For global installation (to generate extensions outside of a Spree project):

```bash
gem install spree_cli
```

## Commands

### Create New Extension

Generate a new Spree extension with all the necessary boilerplate:

```bash
spree extension my_extension
```

This creates a new directory `spree_my_extension` with:

```
spree_my_extension/
├── app/
│   ├── models/
│   ├── controllers/
│   └── views/
├── lib/
│   ├── spree_my_extension.rb
│   ├── spree_my_extension/
│   │   └── engine.rb
│   └── generators/
├── config/
│   ├── routes.rb
│   └── locales/
├── db/
│   └── migrate/
├── spec/
├── Gemfile
├── spree_my_extension.gemspec
├── README.md
└── LICENSE
```

### Extension Options

```bash
# Create extension with specific options
spree extension my_extension --path=/custom/path

# View help
spree help extension
```

## Extension Development

After creating an extension:

```bash
cd spree_my_extension

# Install dependencies
bundle install

# Create test application
bundle exec rake test_app

# Run tests
bundle exec rspec

# Build gem
gem build spree_my_extension.gemspec
```

### Extension Structure

Generated extensions follow Spree conventions:

```ruby
# lib/spree_my_extension/engine.rb
module SpreeMyExtension
  class Engine < Rails::Engine
    require 'spree/core'
    isolate_namespace Spree
    engine_name 'spree_my_extension'

    config.autoload_paths += %W(#{config.root}/lib)

    initializer 'spree_my_extension.environment', before: :load_config_initializers do |_app|
      SpreeMyExtension::Config = SpreeMyExtension::Configuration.new
    end

    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), '../../app/**/*_decorator*.rb')) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end
    end

    config.to_prepare(&method(:activate).to_proc)
  end
end
```

### Adding Models

```ruby
# app/models/spree/my_model.rb
module Spree
  class MyModel < Spree.base_class
    # Model implementation
  end
end
```

### Adding Controllers

```ruby
# app/controllers/spree/admin/my_models_controller.rb
module Spree
  module Admin
    class MyModelsController < ResourceController
      # Controller implementation
    end
  end
end
```

### Adding Migrations

```bash
cd spree_my_extension
bin/rails g migration CreateSpreeMyModels
```

## Publishing Extensions

1. Update version in `lib/spree_my_extension/version.rb`
2. Update `CHANGELOG.md`
3. Build and publish:

```bash
gem build spree_my_extension.gemspec
gem push spree_my_extension-1.0.0.gem
```

## Usage

### In a Spree Application

Add your extension to the application's Gemfile:

```ruby
gem 'spree_my_extension', '~> 1.0'
```

Run installation:

```bash
bundle install
bin/rails g spree_my_extension:install
```

## Documentation

- [Extension Development Guide](https://docs.spreecommerce.org/developer/extending-spree/extensions)
- [Creating Extensions Tutorial](https://docs.spreecommerce.org/developer/tutorials/extensions)
- [Spree Extensions Directory](https://spreecommerce.org/extensions)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests
5. Submit a pull request