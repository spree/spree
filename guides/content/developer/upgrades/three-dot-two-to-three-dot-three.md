---
title: Upgrading Spree from 3.2.x to 3.3.x
section: upgrades
---

This guide covers upgrading a 3.2.x Spree store, to a 3.3.x store.

### Update your Rails version to 5.1

Please follow the
[official Rails guide](http://edgeguides.rubyonrails.org/upgrading_ruby_on_rails.html#upgrading-from-rails-5-0-to-rails-5-1)
to upgrade your store.

### Update Gemfile

```ruby
gem 'spree', '~> 3.3.0'
gem 'spree_auth_devise', '~> 3.3'
gem 'spree_gateway', '~> 3.3'
```

### Update your extensions

We're changing how extensions dependencies work. Previously you had to match
extension branch to Spree branch. Starting from Spree 3.2 release date `master` branch of all
`spree-contrib` extensions should work with Spree >= `3.1` and < `4.0`. Please change
your extensions in Gemfile eg.:

from:

```ruby
gem 'spree_braintree_vzero', github: 'spree-contrib/spree_braintree_vzero', branch: '3-1-stable'
```

to:

```ruby
gem 'spree_braintree_vzero', github: 'spree-contrib/spree_braintree_vzero'
```

### Run `bundle update`

### Install missing migrations

```bash
rails spree:install:migrations
rails spree_auth:install:migrations
rails spree_gateway:install:migrations
```

### Run migrations

```bash
rails db:migrate
```

### Include `UserMethods` in your `User` class

With this release we're not including this automatically. You need to do it manually if you're not using `spree_auth_devise`.

You need to include `Spree::UserMethods` in your user class, eg.

```ruby
class User
  include UserAddress
  include UserMethods
  include UserPaymentSource
end
```

### Update `aws-sdk` gem to `>= 2.0`

Spree 3.3 comes with paperclip 5.1 support so if you're using Amazon S3 storage you need to change in your Gemfile, from:

```ruby
gem 'aws-sdk', '< 2.0'
```

to:

```ruby
gem 'aws-sdk', '>= 2.0'
```

and run `bundle update aws-sdk`

In your paperclip configuration you also need to specify
`s3_region` attribute eg. https://github.com/spree/spree/blame/master/guides/content/developer/customization/s3_storage.md#L27

Seel also [RubyThursday episode](https://rubythursday.com/episodes/ruby-snack-27-upgrade-paperclip-and-aws-sdk-in-prep-for-rails-5) walkthrough of upgrading paperclip in your project.

### Add jquery.validate to your project if you've used it directly from Spree

If your application.js file includes line
 `//= require jquery.validate/jquery.validate.min`
you will need to add it this file manually to your project because this library was
[removed from Spree in favour of native HTML5 validation](https://github.com/spree/spree/pull/8173).

## Read the release notes

For information about changes contained within this release, please read the [3.3.0 Release Notes](http://guides.spreecommerce.org/release_notes/spree_3_3_0.html).

## Verify that everything is OK

Run you test suite, click around in your store and make sure it's performing as normal. Fix any deprecation warnings you see.
