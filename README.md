# Spree Commerce

<a href="https://guides.spreecommerce.org/release_notes/4_1_0.html"><img src="https://spreecommerce.org/wp-content/uploads/2020/03/spree-4_1-mobile-first-customizable-ux-1400x800-0_20.png" /></a>

* Join our Slack at [slack.spreecommerce.org](http://slack.spreecommerce.org/)
* [Contact us](https://spreecommerce.org/contact/) to start a new project or get tech support
* [DEMO](https://spreecommerce.org/spree-commerce-demo-explainer/) of the new Spree UX introduced in Spree 4.1
* [9 good reasons to upgrade to Spree 4.1](https://spreecommerce.org/spree-commerce-4-1-is-now-available-9-reasons-to-upgrade-or-use-it-for-a-new-e-commerce-project/) or use it for a new project
* [Success Stories](https://spreecommerce.org/stories/)
* [Integrations](https://spreecommerce.org/integrations/)
* [Extensions](https://github.com/spree/spree#extensions)
* [Documentation](http://guides.spreecommerce.org)
* [Roadmap](https://github.com/spree/spree/milestones?direction=asc&sort=due_date&state=open)
* [Maintenance Policy](https://github.com/spree/spree/wiki/Maintenance-Policy)

[![Gem Version](https://badge.fury.io/rb/spree.svg)](https://badge.fury.io/rb/spree) [![Circle CI](https://circleci.com/gh/spree/spree.svg?style=shield)](https://circleci.com/gh/spree/spree/tree/master)
[![Code Climate](https://codeclimate.com/github/spree/spree.svg)](https://codeclimate.com/github/spree/spree)
[![Test Coverage](https://api.codeclimate.com/v1/badges/8277fc2bb0b1f777084f/test_coverage)](https://codeclimate.com/github/spree/spree/test_coverage)
[![Slack Status](http://slack.spreecommerce.org/badge.svg)](http://slack.spreecommerce.org)

**Spree** is a complete open source e-commerce solution built with Ruby on Rails. It
was started by Sean Schofield and is now developed by [Spark Solutions](http://sparksolutions.co). We're open to [contributions](#contributing).

Spree consists of several different gems (modules), each of which are maintained
in a single repository and documented in a single set of
[online documentation](http://guides.spreecommerce.org/).

* **spree_api** ([REST API v2](https://guides.spreecommerce.org/api/v2) with [JavaScript / TypeScript SDK](https://github.com/spree/spree-storefront-api-v2-js-sdk) and [REST API v1](https://guides.spreecommerce.org/api/))
* **spree_graphql** (GraphQL API - [coming soon](https://github.com/spree/spree/issues/9176))
* **spree_frontend** (mobile-first, blazing fast and customizable storefront)
* **spree_backend** (feature rich Admin Panel)
* **spree_cmd** (command-line tools for developers)
* **spree_core** (models, services & mailers, the basic components of Spree)
* **spree_sample** (sample data for demo purposes)

## Demo

Go to: https://demo.spreecommerce.org/
Explore demo features: https://spreecommerce.org/spree-commerce-demo-explainer/

Or fire up your own demo on Heroku:

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/spree/spree/tree/4-1-stable)

Admin panel credentials for your own Heroku demo:

* login: `spree@example.com`
* password: `spree123`

## Installation

### Create new Rails app (optional)

If you're starting a new application from scrach run:

```bash
rails new my_store
cd my_store
```

You can **add Spree to your existing Rails application** as well.

### Add Spree gems to your `Gemfile`

#### Rails 6.0

```ruby
gem 'spree', '~> 4.1'
gem 'spree_auth_devise', '~> 4.2'
gem 'spree_gateway', '~> 3.7'
```

#### Rails 5.2

```ruby
gem 'spree', '~> 3.7.0'
gem 'spree_auth_devise', '~> 3.5'
gem 'spree_gateway', '~> 3.4'
```

To see what rails version are you using run this command:

```bash
rails -v
```

Older rails versions are also supported: [Rails 5.1](https://guides.spreecommerce.org/release_notes/3_5_0.html), [Rails 5.0](https://guides.spreecommerce.org/release_notes/3_2_0.html), [Rails 4.2](https://guides.spreecommerce.org/release_notes/3_1_0.html)

### Install gems

```bash
bundle install
```

**Note**: if you run into `Bundler could not find compatible versions for gem "sprockets":` error message, please run

```bash
bundle update
```

### Use the install generators to set up Spree

```shell
bundle exec rails g spree:install --user_class=Spree::User
bundle exec rails g spree:auth:install
bundle exec rails g spree_gateway:install
```

## Installation options

By default, the installation generator (`rails g spree:install`) will run
migrations as well as adding seed and sample data and will copy storefront data
for easy customization (if `spree_frontend` available). This can be disabled using

```shell
rails g spree:install --migrate=false --sample=false --seed=false --copy_storefront=false
```

You can always perform any of these steps later by using these commands.

```shell
bundle exec rake railties:install:migrations
bundle exec rails db:migrate
bundle exec rails db:seed
bundle exec rake spree_sample:load
bundle exec rails g spree:frontend:copy_storefront
```

### Headless installation

To use Spree in [API-only mode](https://guides.spreecommerce.org/api/overview/) you need to replace `spree` with `spree_api` in your project Gemfile. This will skip Storefront and Admin Panel. If you would want to include the Admin Panel please add `spree_backend` to your Gemfile.

## Run rails sever

```bash
rails s
```

## Browse Storefront

Go to http://localhost:3000

## Browse Admin Panel

Go to http://localhost:3000/admin

## Extensions

Spree Extensions provide additional features not present in the Core system.

| Extension | Spree 3.2+ support | Description |
| --- | --- | --- |
| [spree_analytics_trackers](https://github.com/spree-contrib/spree_analytics_trackers) | [![Build Status](https://travis-ci.org/spree-contrib/spree_analytics_trackers.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_analytics_trackers) | Adds support for Analytics Trackers (Google Analytics & Segment)
| [spree_avatax_official](https://github.com/spree-contrib/spree_avatax_official) | [![Build Status](https://travis-ci.org/spree-contrib/spree_avatax_official.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_avatax_official) | Improve your Spree store's sales tax decision automation with Avalara AvaTax
| [spree_auth_devise](https://github.com/spree/spree_auth_devise) | [![Build Status](https://travis-ci.org/spree/spree_auth_devise.svg?branch=master)](https://travis-ci.org/spree/spree_auth_devise) | Provides authentication services for Spree, using the Devise gem.
| [better_spree_paypal_express](https://github.com/spree-contrib/better_spree_paypal_express) | [![Build Status](https://travis-ci.org/spree-contrib/better_spree_paypal_express.svg?branch=master)](https://travis-ci.org/spree-contrib/better_spree_paypal_express) | This is the official Paypal Express extension for Spree.
| [spree_braintree_vzero](https://github.com/spree-contrib/spree_braintree_vzero) | [![Build Status](https://travis-ci.org/spree-contrib/spree_braintree_vzero.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_braintree_vzero) | Official Spree Braintree v.zero + PayPal extension |
| [spree_contact_us](https://github.com/spree-contrib/spree_contact_us) | [![Build Status](https://travis-ci.org/spree-contrib/spree_contact_us.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_contact_us) | Adds Contact Us form |
| [spree_digital](https://github.com/spree-contrib/spree_digital) | [![Build Status](https://travis-ci.org/spree-contrib/spree_digital.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_digital) | A Spree extension to enable downloadable products |
| [spree_gateway](https://github.com/spree/spree_gateway) | [![Build Status](https://travis-ci.org/spree/spree_gateway.svg?branch=master)](https://travis-ci.org/spree/spree_gateway) | Payment Gateways (Stripe, Apple Pay, Braintree, Authorize.net and many others)
| [spree_editor](https://github.com/spree-contrib/spree_editor) | [![Build Status](https://travis-ci.org/spree-contrib/spree_editor.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_editor) | Rich text editor for Spree with Image and File uploading in-place |
| [spree_globalize](https://github.com/spree-contrib/spree_globalize) | [![Build Status](https://travis-ci.org/spree-contrib/spree_globalize.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_globalize) | Adds support for model translations (multi-language stores)
| [spree_i18n](https://github.com/spree-contrib/spree_i18n) | [![Build Status](https://travis-ci.org/spree-contrib/spree_i18n.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_i18n) | I18n translation files for Spree Commerce
| [spree-mollie-gateway](https://github.com/mollie/spree-mollie-gateway) | [![Build Status](https://travis-ci.org/mollie/spree-mollie-gateway.svg?branch=master)](https://github.com/mollie/spree-mollie-gateway) | Official [Mollie](https://www.mollie.com) payment gateway for Spree Commerce. |
| [spree_multi_currency](https://github.com/spree-contrib/spree_multi_currency) | [![Build Status](https://travis-ci.org/spree-contrib/spree_multi_currency.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_multi_currency) | Provides UI to allow configuring multiple currencies in Spree |
| [spree-multi-domain](https://github.com/spree-contrib/spree-multi-domain) | [![Build Status](https://travis-ci.org/spree-contrib/spree-multi-domain.svg?branch=master)](https://travis-ci.org/spree-contrib/spree-multi-domain) | Multiple Spree stores on different domains - single unified backed for processing orders
| [spree_multi_vendor](https://github.com/spree-contrib/spree_multi_vendor) | [![Build Status](https://travis-ci.org/spree-contrib/spree_multi_vendor.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_multi_vendor) | Spree Multi Vendor Marketplace extension |
| [spree-product-assembly](https://github.com/spree-contrib/spree-product-assembly) | [![Build Status](https://travis-ci.org/spree-contrib/spree-product-assembly.svg?branch=master)](https://travis-ci.org/spree-contrib/spree-product-assembly) | Product Bundles |
| [spree_recently_viewed](https://github.com/spree-contrib/spree_recently_viewed) | [![Build Status](https://travis-ci.org/spree-contrib/spree_recently_viewed.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_recently_viewed) | Recently viewed products in Spree |
| [spree_related_products](https://github.com/spree-contrib/spree_related_products) | [![Build Status](https://travis-ci.org/spree-contrib/spree_related_products.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_related_products) | Related products extension for Spree
| [spree_social](https://github.com/spree-contrib/spree_social) |[![Build Status](https://travis-ci.org/spree-contrib/spree_social.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_social)  | Building block for spree social networking features (provides authentication and account linkage) |
| [spree_sitemap](https://github.com/spree-contrib/spree_sitemap) | [![Build Status](https://travis-ci.org/spree-contrib/spree_sitemap.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_sitemap) | Sitemap Generator for Spree  |
| [spree_shared](https://github.com/spree-contrib/spree_shared) | [![Build Status](https://travis-ci.org/spree-contrib/spree_shared.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_shared) | Multi-tenancy for Spree using Apartment (per tenant databases)  |
| [spree_static_content](https://github.com/spree-contrib/spree_static_content) | [![Build Status](https://travis-ci.org/spree-contrib/spree_static_content.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_static_content) | Manage static pages for Spree |
| [spree_volume_pricing](https://github.com/spree-contrib/spree_volume_pricing) | [![Build Status](https://travis-ci.org/spree-contrib/spree_volume_pricing.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_volume_pricing) | It determines the price for a particular product variant with predefined ranges of quantities
| [spree_wishlist](https://github.com/spree-contrib/spree_wishlist) | [![Build Status](https://travis-ci.org/spree-contrib/spree_wishlist.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_wishlist) | Wishlist extension for Spree |

## Developing Spree

Please [follow this guide](https://guides.spreecommerce.org/developer/tutorials/developing_spree.html)

## Contributing

Spree is an open source project and we encourage contributions. Please review the
[contributing guidelines](https://github.com/spree/spree/blob/master/.github/CONTRIBUTING.md)
before contributing.

In the spirit of [free software](http://www.fsf.org/licensing/essays/free-sw.html), **everyone** is encouraged to help improve this project.

Here are some ways **you** can contribute:

* by using prerelease versions / master branch
* by reporting [bugs](https://github.com/spree/spree/issues/new)
* by [translating to a new language](https://github.com/spree/spree_i18n/tree/master/config/locales)
* by writing or editing [documentation](https://github.com/spree/spree/blob/master/.github/CONTRIBUTING.md)
* by writing [specs](https://github.com/spree/spree/labels/need_specs)
* by writing [needed code](https://github.com/spree/spree/labels/feature_request) or [finishing code](https://github.com/spree/spree/labels/address_feedback)
* by [refactoring code](https://github.com/spree/spree/labels/address_feedback)
* by reviewing [pull requests](https://github.com/spree/spree/pulls)
* by verifying [issues](https://github.com/spree/spree/labels/unverified)

## License

Spree is released under the [New BSD License](https://github.com/spree/spree/blob/master/license.md).

## About Spark Solutions

[![Spark Solutions](http://sparksolutions.co/wp-content/uploads/2015/01/logo-ss-tr-221x100.png)][spark]

[Spark Solutions][spark] is a software development agency specialized in Ruby on Rails, Spree Commerce and Javascript development. We’ve been leading Spree open-source efforts since 2016 as its core team. We also do client work. Our project teams consist of UX and UI designers, Software Engineers, Testers and Project Managers practicing agile project delivery. We’ll integrate our team with yours to jointly architect, deliver, maintain and scale the software products you need. You drive the project with requirements and acceptance testing and we help you deliver faster using industry-standard project management and comms best practices.

We are passionate about open source software.
We are [available for hire][spark].

[spark]:http://sparksolutions.co?utm_source=github
