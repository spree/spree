# Spree

Ruby gems that power Spree Commerce — models, services, APIs, admin dashboard, and transactional emails.

## Structure

```
spree/
├── core/               # spree_core — models, services, business logic
├── api/                # spree_api — REST APIs (Store API + Admin API)
├── admin/              # spree_admin — admin dashboard
├── emails/             # spree_emails — transactional emails (optional)
├── spree.gemspec       # meta-gem (installs core + api)
├── template.rb         # Rails application template for new projects
├── Gemfile             # shared dependencies for development/testing
├── Rakefile            # gem build, test, and release tasks
└── lib/                # shared generators
```

## Installation

Add to your Rails application's Gemfile:

```ruby
gem 'spree'
gem 'spree_admin'   # optional
gem 'spree_emails'  # optional
```

Or use the Rails application template:

```bash
rails new my_store -m https://raw.githubusercontent.com/spree/spree/main/spree/template.rb
```

## Running Tests

Each gem has its own test suite. First install the shared dependencies, then set up the specific gem:

```bash
# 1. Install shared dependencies (required once)
cd spree
bundle install

# 2. Set up and run tests for a specific gem (e.g. core)
cd core
bundle install
bundle exec rake test_app   # generates a dummy Rails app for testing
bundle exec rspec
```

Replace `core` with `api`, `admin`, or `emails` to test other gems.

By default tests run against SQLite3. To use PostgreSQL:

```bash
DB=postgres DB_USERNAME=postgres DB_PASSWORD=password DB_HOST=localhost bundle exec rake test_app
```

Run a single spec:

```bash
cd spree/core
bundle exec rspec spec/models/spree/product_spec.rb
bundle exec rspec spec/models/spree/product_spec.rb:42
```

### Parallel tests

```bash
cd spree/core
bundle exec rake parallel_setup
bundle exec parallel_rspec spec
```

## Building & Releasing Gems

```bash
cd spree
bundle exec rake gem:build     # build all gems
bundle exec rake gem:release   # push to RubyGems
```

## Generating TypeScript Types

Types for the SDK are generated from API serializers:

```bash
cd spree/api
bundle exec rake typelizer:generate
```

## Generating OpenAPI Spec

The Store API OpenAPI specification is generated from rswag integration tests:

```bash
cd spree/api
bundle exec rake rswag:specs:swaggerize
```

Output: `docs/api-reference/store.yaml`
