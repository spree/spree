
![Spree](spree_logo.png)

* [Join our Slack](http://slack.spreecommerce.com/)
* [Documentation](http://guides.spreecommerce.com)
* [2016 Development Roadmap](https://github.com/spree/spree/wiki/Spree-Commerce-development-roadmap-2016)
* [Vote & comment on roadmap features](https://trello.com/b/ta4WU3AX/spree-roadmap)

[![Circle CI](https://circleci.com/gh/spree/spree.svg?style=svg)](https://circleci.com/gh/spree/spree)
[![Code Climate](https://codeclimate.com/github/spree/spree.png)](https://codeclimate.com/github/spree/spree)
[![codebeat](https://codebeat.co/badges/16feb8a2-abf0-4fbb-a130-20b689efcfc0)](https://codebeat.co/projects/github-com-spree-spree)
[![Slack Status](http://slack.spreecommerce.com/badge.svg)](http://slack.spreecommerce.com)
[![Issue Stats](http://issuestats.com/github/spree/spree/badge/pr)](http://issuestats.com/github/spree/spree)
[![Issue Stats](http://issuestats.com/github/spree/spree/badge/issue)](http://issuestats.com/github/spree/spree)

**Spree** is a complete open source e-commerce solution built with Ruby on Rails. It
was originally developed by Sean Schofield and is now maintained by developers from [Spark Solutions](http://sparksolutions.co) and [Vinsol](http://vinsol.com/). We're open to [contributions](#contributing) and accepting new [Core Team](https://github.com/spree/spree/wiki/Core-Team) members.

Spree consists of several different gems, each of which are maintained
in a single repository and documented in a single set of
[online documentation](http://guides.spreecommerce.com/).

* spree_api (RESTful API)
* spree_frontend (Customer frontend)
* spree_backend (Admin panel)
* spree_cmd (Command-line tools)
* spree_core (Models & Mailers, the basic components of Spree that it can't run without)
* spree_sample (Sample data)


Getting Started
----------------------

Add Spree gems to your Gemfile:

```ruby
gem 'spree', '~> 3.0.7'
gem 'spree_auth_devise', '~> 3.0.5'
gem 'spree_gateway', '~> 3.0.0'
```

Run `bundle install`

Use the install generators to set up Spree:

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
migrations as well as adding seed and sample data. This can be disabled using

```shell
rails g spree:install --migrate=false --sample=false --seed=false
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


Performance
----------------------

You may notice that your Spree store runs slowly in development enviornment. This can be because in development each asset (css and javascript) is loaded separately. You can disable it by adding the following line to `config/environments/development.rb`.

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

Create a sandbox Rails application for testing purposes which automatically perform all necessary database setup

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
bundle exec rake test_app
bundle exec rspec spec
```

If you would like to run specs against a particular database you may specify the
dummy apps database, which defaults to sqlite3.
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

And also ensure that you have [PhantomJS](http://phantomjs.org/) installed as well:

```shell
brew update && brew install phantomjs
```

To execute all the tests, you may want to run this command at the
root of the Spree project to generate test applications and run
specs for all the facets:
```shell
bash build.sh
```


Contributing
----------------------

Spree is an open source project and we encourage contributions. Please review the
[contributing guidelines](CONTRIBUTING.md)
before contributing.

In the spirit of [free software](http://www.fsf.org/licensing/essays/free-sw.html), **everyone** is encouraged to help improve this project.

Here are some ways **you** can contribute:

* by using prerelease versions / master branch
* by reporting [bugs](https://github.com/spree/spree/issues/new)
* by [translating to a new language](https://github.com/spree/spree_i18n/tree/master/config/locales)
* by writing or editing [documentation](http://guides.spreecommerce.com/developer/contributing.html#contributing-to-the-documentation)
* by writing [specs](https://github.com/spree/spree/labels/need_specs)
* by writing [needed code](https://github.com/spree/spree/labels/feature_request) or [finishing code](https://github.com/spree/spree/labels/address_feedback)
* by [refactoring code](https://github.com/spree/spree/labels/address_feedback)
* by reviewing [pull requests](https://github.com/spree/spree/pulls)
* by verifying [issues](https://github.com/spree/spree/labels/unverified)

License
----------------------

Spree is released under the [New BSD License](https://github.com/spree/spree/blob/master/license.md).
