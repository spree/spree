<a href="https://spreecommerce.org/contact/" target="_blank" rel="nofollow"><img src="https://spreecommerce.org/wp-content/uploads/2019/10/spree_commerce_new_ux_template.jpg" /></a>

* Join our Slack at [slack.spreecommerce.org](http://slack.spreecommerce.org/)
* [Start a new project or get tech support](https://spreecommerce.org/contact/)
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
was originally developed by Sean Schofield and is now maintained by [Spark Solutions](http://sparksolutions.co). We're open to [contributions](#contributing) and accepting new [Core Team](https://github.com/spree/spree/wiki/Core-Team) members.

Spree consists of several different gems, each of which are maintained
in a single repository and documented in a single set of
[online documentation](http://guides.spreecommerce.org/).

* **spree_api** (new [REST API v2](https://guides.spreecommerce.org/api/v2) and legacy [REST API v1](https://guides.spreecommerce.org/api/), [GraphQL support](https://github.com/spree/spree/issues/9176) coming soon) - we also have an official [API v2 JavaScript / TypeScript SDK](https://github.com/spree/spree-storefront-api-v2-js-sdk)
* **spree_frontend** (default Rails customer frontend)
* **spree_backend** (Admin Panel)
* **spree_cmd** (Command-line tools)
* **spree_core** (Models, Services & Mailers, the basic components of Spree that it can't run without)
* **spree_sample** (Sample data)

You don't need to install all of the components. Only the **Core** is mandatory. 

Demo
----

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/spree/spree/tree/4-0-stable)

If you want to run the demo on your local machine, you can use our docker image. It will download and run sample Spree application on http://localhost:3000
```shell
docker run --rm -it -p 3000:3000 spreecommerce/spree:3.6.4
```

Admin Panel credentials - login: `spree@example.com` / password: `spree123`


Getting Started
----------------------

### Add Spree gems to your `Gemfile`

#### Rails 6.0

```ruby
gem 'spree', '~> 4.0'
gem 'spree_auth_devise', '~> 4.0'
gem 'spree_gateway', '~> 3.6'
```

#### Rails 5.2

```ruby
gem 'spree', '~> 3.7.0'
gem 'spree_auth_devise', '~> 3.5'
gem 'spree_gateway', '~> 3.4'
```

#### Rails 5.1

```ruby
gem 'spree', '~> 3.5.0'
gem 'spree_auth_devise', '~> 3.5'
gem 'spree_gateway', '~> 3.4'
```

#### Rails 5.0

```ruby
gem 'spree', '~> 3.2.7'
gem 'spree_auth_devise', '~> 3.5'
gem 'spree_gateway', '~> 3.4'
```

### Run `bundle install`

### Use the install generators to set up Spree

```shell
rails g spree:install --user_class=Spree::User
rails g spree:auth:install
rails g spree_gateway:install
```

Installation options
----------------------

Alternatively, if you want to use the bleeding edge version of Spree, add this to your Gemfile:

```ruby
gem 'spree', github: 'spree/spree'
gem 'spree_auth_devise', github: 'spree/spree_auth_devise'
gem 'spree_gateway', github: 'spree/spree_gateway'
```

**Note: The master branch is not guaranteed to ever be in a fully functioning
state. It is unwise to use this branch in a production system you care deeply
about.**

By default, the installation generator (`rails g spree:install`) will run
migrations as well as adding seed and sample data and will copy frontend views
for easy customization (if spree_frontend available). This can be disabled using

```shell
rails g spree:install --migrate=false --sample=false --seed=false --copy_views=false
```

You can always perform any of these steps later by using these commands.

```shell
bundle exec rake railties:install:migrations
bundle exec rake db:migrate
bundle exec rake db:seed
bundle exec rake spree_sample:load
```

Browse Store
----------------------

http://localhost:3000

Browse Admin Interface
----------------------

http://localhost:3000/admin

If you have `spree_auth_devise` installed, you can generate a new admin user by running `rake spree_auth:admin:create`.

Extensions
----------------------

Spree Extensions provide additional features not present in the Core system.


| Extension | Spree 3.2+ support | Description |
| --- | --- | --- |
| [spree_gateway](https://github.com/spree/spree_gateway) | [![Build Status](https://travis-ci.org/spree/spree_gateway.svg?branch=master)](https://travis-ci.org/spree/spree_gateway) | Community supported Spree Payment Method Gateways
| [spree_auth_devise](https://github.com/spree/spree_auth_devise) | [![Build Status](https://travis-ci.org/spree/spree_auth_devise.svg?branch=master)](https://travis-ci.org/spree/spree_auth_devise) | Provides authentication services for Spree, using the Devise gem.
| [spree_i18n](https://github.com/spree-contrib/spree_i18n) | [![Build Status](https://travis-ci.org/spree-contrib/spree_i18n.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_i18n) | I18n translation files for Spree Commerce
| [spree-multi-domain](https://github.com/spree-contrib/spree-multi-domain) | [![Build Status](https://travis-ci.org/spree-contrib/spree-multi-domain.svg?branch=master)](https://travis-ci.org/spree-contrib/spree-multi-domain) | Multiple Spree stores on different domains - single unified backed for processing orders
| [spree_multi_currency](https://github.com/spree-contrib/spree_multi_currency) | [![Build Status](https://travis-ci.org/spree-contrib/spree_multi_currency.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_multi_currency) | Provides UI to allow configuring multiple currencies in Spree |
| [spree_multi_vendor](https://github.com/spree-contrib/spree_multi_vendor) | [![Build Status](https://travis-ci.org/spree-contrib/spree_multi_vendor.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_multi_vendor) | Spree Multi Vendor Marketplace extension |
| [spree-mollie-gateway](https://github.com/mollie/spree-mollie-gateway) | [![Build Status](https://travis-ci.org/mollie/spree-mollie-gateway.svg?branch=master)](https://github.com/mollie/spree-mollie-gateway) | Official [Mollie](https://www.mollie.com) payment gateway for Spree Commerce. |
| [spree_braintree_vzero](https://github.com/spree-contrib/spree_braintree_vzero) | [![Build Status](https://travis-ci.org/spree-contrib/spree_braintree_vzero.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_braintree_vzero) | Official Spree Braintree v.zero + PayPal extension |
| [spree_address_book](https://github.com/spree-contrib/spree_address_book) | [![Build Status](https://travis-ci.org/spree-contrib/spree_address_book.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_address_book) | Adds address book for users to Spree |
| [spree_digital](https://github.com/spree-contrib/spree_digital) | [![Build Status](https://travis-ci.org/spree-contrib/spree_digital.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_digital) | A Spree extension to enable downloadable products |
| [spree_social](https://github.com/spree-contrib/spree_social) |[![Build Status](https://travis-ci.org/spree-contrib/spree_social.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_social)  | Building block for spree social networking features (provides authentication and account linkage) |
| [spree_related_products](https://github.com/spree-contrib/spree_related_products) | [![Build Status](https://travis-ci.org/spree-contrib/spree_related_products.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_related_products) | Related products extension for Spree
| [spree_static_content](https://github.com/spree-contrib/spree_static_content) | [![Build Status](https://travis-ci.org/spree-contrib/spree_static_content.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_static_content) | Manage static pages for Spree |
| [spree-product-assembly](https://github.com/spree-contrib/spree-product-assembly) | [![Build Status](https://travis-ci.org/spree-contrib/spree-product-assembly.svg?branch=master)](https://travis-ci.org/spree-contrib/spree-product-assembly) | Adds opportunity to make bundle of products |
| [spree_editor](https://github.com/spree-contrib/spree_editor) | [![Build Status](https://travis-ci.org/spree-contrib/spree_editor.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_editor) | Rich text editor for Spree with Image and File uploading in-place |
| [spree_recently_viewed](https://github.com/spree-contrib/spree_recently_viewed) | [![Build Status](https://travis-ci.org/spree-contrib/spree_recently_viewed.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_recently_viewed) | Recently viewed products in Spree |
| [spree_wishlist](https://github.com/spree-contrib/spree_wishlist) | [![Build Status](https://travis-ci.org/spree-contrib/spree_wishlist.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_wishlist) | Wishlist extension for Spree |
| [spree_sitemap](https://github.com/spree-contrib/spree_sitemap) | [![Build Status](https://travis-ci.org/spree-contrib/spree_sitemap.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_sitemap) | Sitemap Generator for Spree  |
| [spree_volume_pricing](https://github.com/spree-contrib/spree_volume_pricing) | [![Build Status](https://travis-ci.org/spree-contrib/spree_volume_pricing.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_volume_pricing) | It determines the price for a particular product variant with predefined ranges of quantities
| [better_spree_paypal_express](https://github.com/spree-contrib/better_spree_paypal_express) | [![Build Status](https://travis-ci.org/spree-contrib/better_spree_paypal_express.svg?branch=master)](https://travis-ci.org/spree-contrib/better_spree_paypal_express) | This is the official Paypal Express extension for Spree.
| [spree_globalize](https://github.com/spree-contrib/spree_globalize) | [![Build Status](https://travis-ci.org/spree-contrib/spree_globalize.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_globalize) | Adds support for model translations (multi-language stores)
| [spree_avatax_official](https://github.com/spree-contrib/spree_avatax_official) | [![Build Status](https://travis-ci.org/spree-contrib/spree_avatax_official.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_avatax_official) | Improve your Spree store's sales tax decision automation with Avalara AvaTax
| [spree_analytics_trackers](https://github.com/spree-contrib/spree_analytics_trackers) | [![Build Status](https://travis-ci.org/spree-contrib/spree_analytics_trackers.svg?branch=master)](https://travis-ci.org/spree-contrib/spree_analytics_trackers) | Adds support for Analytics Trackers (Google Analytics & Segment)

Performance
----------------------

You may notice that your Spree store runs slowly in development environment. This can be because in development each asset (css and javascript) is loaded separately. You can disable it by adding the following line to `config/environments/development.rb`.

```ruby
config.assets.debug = false
```


Developing Spree
----------------------

Spree is meant to be run within the context of Rails application and the source code is essentially a collection of gems. You can easily create a sandbox
application inside of your cloned source directory for testing purposes.


Clone the Git repo

```shell
git clone git://github.com/spree/spree.git
cd spree
```

Install the gem dependencies

```shell
bundle install
```

### Sandbox

Create a sandbox Rails application for testing purposes which automatically performs all necessary database setup

```shell
bundle exec rake sandbox
```

Start the server

```shell
cd sandbox
rails server
```

### Running Tests

We use [CircleCI](https://circleci.com/) to run the tests for Spree.

You can see the build statuses at [https://circleci.com/gh/spree/spree](https://circleci.com/gh/spree/spree).

---

Each gem contains its own series of tests, and for each directory, you need to
do a quick one-time creation of a test application and then you can use it to run
the tests.  For example, to run the tests for the core project.
```shell
cd core
BUNDLE_GEMFILE=../Gemfile bundle exec rake test_app
bundle exec rspec spec
```

If you would like to run specs against a particular database you may specify the
dummy app's database, which defaults to sqlite3.
```shell
DB=postgres bundle exec rake test_app
```

If you want to run specs for only a single spec file
```shell
bundle exec rspec spec/models/spree/state_spec.rb
```

If you want to run a particular line of spec
```shell
bundle exec rspec spec/models/spree/state_spec.rb:7
```

You can also enable fail fast in order to stop tests at the first failure
```shell
FAIL_FAST=true bundle exec rspec spec/models/state_spec.rb
```

If you want to run the simplecov code coverage report
```shell
COVERAGE=true bundle exec rspec spec
```

If you're working on multiple facets of Spree to test,
please ensure that you have a postgres user:

```shell
createuser -s -r postgres
```

And also ensure that you have [ChromeDriver](http://chromedriver.chromium.org) installed as well.
Please follow this
[instruction](https://github.com/SeleniumHQ/selenium/wiki/ChromeDriver) to install it.

To execute all the tests, you may want to run this command at the
root of the Spree project to generate test applications and run
specs for all the facets:
```shell
bash build.sh
```


Contributing
----------------------

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

License
----------------------

Spree is released under the [New BSD License](https://github.com/spree/spree/blob/master/license.md).


About Spark Solutions
----------------------
[![Spark Solutions](http://sparksolutions.co/wp-content/uploads/2015/01/logo-ss-tr-221x100.png)][spark]

Spree is maintained by [Spark Solutions Sp. z o.o.][spark].

We are passionate about open source software.
We are [available for hire][spark].

[spark]:http://sparksolutions.co?utm_source=github
