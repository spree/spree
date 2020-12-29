---
title: Developing Spree
section: tutorial
---

## Overview

Spree is meant to be run within the context of Rails application and the source code is essentially a collection of gems. You can easily create a sandbox application inside of your cloned source directory for testing purposes.

## Setup locally

Clone the Git repo

```shell
git clone git://github.com/spree/spree.git
cd spree
```

Install the gem dependencies

```shell
bundle install
```

### Fix Bundle errors on MacOS

If `bundle install` fails that means you're missing some required system libraries.

Firstly, please [install homebew](https://brew.sh/). With homebrew installed you will need to install some packages needed to run Spree and Rails applications in general:

```bash
brew install openssl mysql postgresql sqlite
```

## Sandbox

Create a sandbox Rails application for testing purposes which automatically performs all necessary database setup

```shell
bundle exec rake sandbox
```

Start the server

```shell
cd sandbox
bundle exec rails s
```

### Performance in development mode

You may notice that your Spree store runs slower in development environment. This can be because in development each asset (css and javascript) is loaded separately. You can disable it by adding the following line to `config/environments/development.rb`.

```ruby
config.assets.debug = false
```

Also in development caching is disabled by default. To turn on caching run:

```bash
bundle exec rails dev:cache
```

You will need to restart rails server after this change.

## Running Tests

We use [CircleCI](https://circleci.com/) to run the tests for Spree.

You can see the build statuses at [https://circleci.com/gh/spree/spree](https://circleci.com/gh/spree/spree).

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
DB=postgres BUNDLE_GEMFILE=../Gemfile bundle exec rake test_app
```

If you want to run specs for only a single spec file

```shell
cd core
bundle exec rspec spec/models/spree/state_spec.rb
```

If you want to run a particular line of spec

```shell
cd core
bundle exec rspec spec/models/spree/state_spec.rb:7
```

### Running integration tests on MacOS

We use chromedriver to run integration tests. To install it please use this command:

```bash
brew cask install chromedriver
```
