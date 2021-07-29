---
title: Testing Spree Applications
section: advanced
---

## Overview

The Spree project currently uses [RSpec](http://rspec.info) for all of its tests. Each of the gems that makes up Spree has a test suite that can be run to verify the code base.

The Spree test code is an evolving story. We started out with RSpec, then switched to Shoulda and now we're back to RSpec. RSpec has evolved considerably since we first tried it. When looking to improve the test coverage of Spree we took another look at RSpec and it was the clear winner in terms of strength of community and documentation.

## Testing Spree Components

Spree consists of several different gems (see the [Understanding Spree](/developer/getting_started/understanding_spree.html#spree-modules) for more details.) Each of these gems has its own test suite which can be found in the `spec` directory. Since these gems are also Rails engines, they can't really be tested in complete isolation - they need to be tested within the context of a Rails application.

You can easily build such an application by using the Rake task designed for this purpose, running it inside the component you want to test:

```bash
bundle exec rake test_app
```

This will build the appropriate test application inside of your `spec` directory. It will also add the gem under test to your `Gemfile` along with the `spree_core` gem (since all of the gems depend on this.)

This rake task will regenerate the application (after deleting the existing one) each time you run it. It will also run the migrations for you automatically so that your test database is ready to go. There is no need to run `rake db:migrate` or `rake db:test:prepare` after running `test_app`.

### Running the Specs

Once your test application has been built, you can then run the specs in the standard RSpec manner:

```bash
bundle exec rspec spec
```

We also set up a build script that mimics what our build server performs. You can run it from the root of the Spree project like this:

```bash
$ bin/build.sh
```

If you wish to run spec for a single file then you can do so like this:

```bash
bundle exec rspec spec/models/spree/state_spec.rb
```

If you wish to test a particular line number of the spec file then you can do so like this:

```bash
bundle exec rspec spec/models/spree/state_spec.rb:7
```

### Using Factories

Spree uses [factory_bot](https://github.com/thoughtbot/factory_bot) to create valid records for testing purpose. All of the factories are also packaged in the gem. So if you are writing an extension or if you just want to play with Spree models then you can use these factories as illustrated below or add it directly to `rails_helper`.

```bash
rails console
require 'spree/testing_support/factories'
```

The `spree_core` gem has a good number of factories which can be used for testing. If you are writing an extension or just testing Spree you can make use of these factories.

## Testing Your Spree Application

Currently, Spree does not come with any tests that you can install into your application. What we would advise doing instead is either copying the tests from the components of Spree and modifying them as you need them or writing your own test suite.

### Unit Testing

Spree itself is well unit-tested. However, when you install a Spree store for the first time, your new app doesn't have any tests of its own. When you start modifying parts of Spree code in your own app, you'll want to add unit tests that cover the extension or modification you made.

### Integration Testing

In the early days, Rails developers preferred fixtures and seed data. As apps grew, fixtures and seed data went out of vogue in favor of Factories. Factories can have their own problems, but at this point are widely considered superior to a large fixture/seed data setup. This [blog post](https://semaphoreci.com/blog/2014/01/14/rails-testing-antipatterns-fixtures-and-factories.html) discusses some background consideration.

Below are some examples for how to create a test suite using Factories (with FactoryBot). As discussed above, you can copy all of the Spree Factories from the Spree core, or you can write your own Factories.

We recommend a fully integration suite covering your checkout. You can also write integration tests for the Admin area, but many people put less attention into this because it is not user-facing. As with the unit tests, the most important thing to test is the modifications you make that make your Spree store different from the default Spree install.



#### Testing as Someone Logged In

If you're using spree_auth_devise, your app already comes with the Warden gem, which can be used to log-in a user through your test suite

```ruby
let(:user) { FactoryBot.create(:user) }
before(:each) do
  login_as(user, scope: :spree_user)
end
```

This lets your Spree app behave as if this user is logged in.
