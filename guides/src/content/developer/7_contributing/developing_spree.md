---
title: Developing Spree
section: contributing
order: 0
---

## Overview

This guide covers all the necessary steps to contributing to Spree source code. We're happy you're here!

## Fork Spree repo

Go to [Spree GitHub repository](https://github.com/spree/spree) and click **Fork** button. This will create a copy of Spree repository on your GitHub account. See [Github Documentation](https://docs.github.com/en/github/getting-started-with-github/fork-a-repo) for more information on forking.

## Setup locally

1. Clone the your fork repository

    ```shell
    git clone git://github.com/your_github_username/spree.git
    cd spree
    ```

2. Install the gem dependencies

    ```shell
    bundle install
    ```

### Fix Bundle errors on MacOS

If `bundle install` fails that means you're missing some required system libraries.

Firstly, ensure you hve [homebrew installed](https://brew.sh/). You will need to install some packages needed to run Spree and Rails applications in general:

```shell
brew install openssl mysql postgresql sqlite imagemagick
```

## Create Sandbox application

Spree is meant to be run within the context of Rails application and the source code is essentially a collection of gems. You can easily create a sandbox application inside of your cloned source directory for testing purposes.

This will setup a Rails application with Spree and some essential extensions and gems pre-installed with some data seeded Sandbox application is not meant to be run on production!

```shell
bundle exec rake sandbox
```

For **headless sandbox** please run:

```shell
SPREE_HEADLESS=true bundle exec rake sandbox
```

By default Sandbox uses **SQLite** database. But you can switch to **PostgreSQL**:

```shell
DB=postgres bundle exec rake sandbox
```

or **MySQL**:

```shell
DB=mysql bundle exec rake sandbox
```

You can also combine those options:

```shell
SPREE_HEADLESS=true DB=postgres bundle exec rake sandbox
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

### Caching

Also in development caching is disabled by default. To turn on caching run:

```bash
bundle exec rails dev:cache
```

You will need to restart rails server after this change.

## Making changes

Create a new branch for your changes. Do not push changes to the main branch. Branch name should be human readable and informative, eg.

* bug fixes: `fix/order-recalculation-total-bug`
* features: `feature/my-new-amazing-feature`

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

## Submitting Changes

Please keep your commit history meaningful and clear. [This guide](https://about.gitlab.com/blog/2018/06/07/keeping-git-commit-history-clean/) covers it quite well and we recommend reading it, not only for Spree project but for any IT project overall.

1. Push your changes to a topic branch in your fork of the repository.

    ```shell
    git push -u origin fix/order-recalculation-total-bug
    ```

2. Create a Pull request - [please follow this guide](https://docs.github.com/en/github/collaborating-with-issues-and-pull-requests/creating-a-pull-request-from-a-fork)

    If your changes references Github issues, please mark which issue you're fixing by adding `Fixes #<number or url of the issue>` in the commit name or PR title/description.
    This will automatically mark that issue as closed when your PR will be merged.

3. Wait for CI to pass

4. If CI passed wait for Spree Core team code review

    We're aiming to review and leave feedback as soon as possible. We'll leave you a meaningul feedback if needed.

## That's a wrap!

Thank you for participating in Open Source and improving Spree - you're awesome!
