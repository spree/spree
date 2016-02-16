# New Spree Commerce roadmap announcement

We are excited to announce a new [Spree Commerce development roadmap](https://github.com/spree/spree/wiki/Spree-Commerce-development-roadmap-2016) for 2016 along with the new [Core Team](https://github.com/spree/spree/wiki/Core-Team).

Future Spree open-source efforts will be coordinated and managed jointly by [Spark Solutions](http://sparksolutions.co) and [Vinsol](http://vinsol.com/) developers who are working daily for merchants using Spree and who have hands on experience in Spree development, customization, maintenance and performance optimization.

We would be excited to welcome new [Core Team](https://github.com/spree/spree/wiki/Core-Team) members! You can make history and join the Core Team. We will evaluate you as a candidate based on the volume and quality of the code contributed to the project as well as sustained efforts in improving the overall quality of the Spree community.

We are determined to support the current contributor community and businesses running Spree worldwide. Spree will be developed and maintained with the next versions to follow.

Together we’ll not only develop future versions but we’ll support Spree developers around the world (mailing list, Slack channel, GitHub issues) in their daily efforts including migrations from 2.x. to 3.x versions.

**For general discussion and support inquiries please use**:
* Spree Slack public channels: http://slack.spreecommerce.com/
* Spree Mailing List: https://groups.google.com/forum/#!forum/spree-user


**THIS README IS FOR THE MASTER BRANCH OF SPREE AND REFLECTS THE WORK CURRENTLY
EXISTING ON THE MASTER BRANCH. IF YOU ARE WISHING TO USE A NON-MASTER BRANCH OF
SPREE, PLEASE CONSULT THAT BRANCH'S README AND NOT THIS ONE.**

SUMMARY
-------

Spree is a complete open source e-commerce solution built with Ruby on Rails. It
was originally developed by Sean Schofield and is now maintained by a dedicated
[core team](https://github.com/spree/spree/wiki/Core-Team). You can find out more by
visiting the [Spree e-commerce project page](http://spreecommerce.com).

Spree actually consists of several different gems, each of which are maintained
in a single repository and documented in a single set of
[online documentation](http://spreecommerce.com/documentation). By requiring the
Spree gem you automatically require all of the necessary gem dependencies which are:

* spree_api (RESTful API)
* spree_frontend (User-facing components)
* spree_backend (Admin area)
* spree_cmd (Command-line tools)
* spree_core (Models & Mailers, the basic components of Spree that it can't run without)
* spree_sample (Sample data)

All of the gems are designed to work together to provide a fully functional
e-commerce platform. It is also possible, however, to use only the pieces you are
interested in. For example, you could use just the barebones spree\_core gem
and perhaps combine it with your own custom backend admin instead of using
spree_api.

[![Circle CI](https://circleci.com/gh/spree/spree.svg?style=svg)](https://circleci.com/gh/spree/spree)
[![Code Climate](https://codeclimate.com/github/spree/spree.png)](https://codeclimate.com/github/spree/spree)
[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/spree/spree)
[![Issue Stats](http://issuestats.com/github/spree/spree/badge/pr)](http://issuestats.com/github/spree/spree)
[![Issue Stats](http://issuestats.com/github/spree/spree/badge/issue)](http://issuestats.com/github/spree/spree)

Installation
------------

The fastest way to get started is by using the spree command line tool
available in the spree gem which will add Spree to an existing Rails application.

```shell
gem install rails -v 4.2.2
gem install spree
rails _4.2.2_ new my_store
spree install my_store
cd my_store
rails g spree:auth:install
```

This will add the Spree gem to your Gemfile, create initializers, copy migrations
and optionally generate sample products and orders.

If you get an "Unable to resolve dependencies" error when installing the Spree gem
then you can try installing just the spree_cmd gem which should avoid any circular
dependency issues.

```shell
gem install spree_cmd
```

To auto accept all prompts while running the install generator, pass -A as an option

```shell
spree install my_store -A
```

To select a specific branch, pass in the `--branch` option. If there is no branch, you
will be given the latest version of either spree_auth_devise or spree_gateway.

```shell
spree install my_store --branch "3-0-stable"
```

Using stable builds and bleeding edge
-------------

To use a stable build of Spree, you can manually add Spree to your
Rails application. Add this line to
your Gemfile.

```ruby
gem 'spree'
```

Alternatively, if you want to use the bleeding edge version of Spree, use this
line:

```ruby
gem 'spree', github: 'spree/spree'
```

Once you've done that, then you can install these gems using this command:

```shell
bundle install
```

Use the install generator to set up Spree:

```shell
rails g spree:install --sample=false --seed=false
```

You can avoid running migrations or generating seed and sample data by passing
in these flags:

```shell
rails g spree:install --migrate=false --sample=false --seed=false
```

You can always perform the steps later by using these commands.

```shell
bundle exec rake railties:install:migrations
bundle exec rake db:migrate
bundle exec rake db:seed
bundle exec rake spree_sample:load
```

Browse Store
------------

http://localhost:nnnn

Browse Admin Interface
----------------------

http://localhost:nnnn/admin

Working with the edge source (latest and greatest features)
-----------------------------------------------------------

The source code is essentially a collection of gems. Spree is meant to be run
within the context of Rails application. You can easily create a sandbox
application inside of your cloned source directory for testing purposes.


1. Clone the Git repo

```shell
git clone git://github.com/spree/spree.git
cd spree
```

2. Install the gem dependencies

```shell
bundle install
```

3. Create a sandbox Rails application for testing purposes (and automatically
perform all necessary database setup)

```shell
bundle exec rake sandbox
```

4. Start the server

```shell
cd sandbox
rails server
```

Performance
-----------

You may notice that your Spree store runs slowly in development mode.  This is
a side-effect of how Rails works in development mode which is to continuously reload
your Ruby objects on each request.  The introduction of the asset pipeline in
Rails 3.1 made default performance in development mode significantly worse. There
are, however, a few tricks to speeding up performance in development mode.

First, in your `config/development.rb`:

```ruby
config.assets.debug = false
```

You can precompile your assets as follows:

```shell
RAILS_ENV=development bundle exec rake assets:precompile
```

If you want to remove precompiled assets (recommended before you commit to Git
and push your changes) use the following rake task:

```shell
RAILS_ENV=development bundle exec rake assets:clean
```

Use Dedicated Spree Devise Authentication
-----------------------------------------
Add the following to your Gemfile

```ruby
gem 'spree_auth_devise', github: 'spree/spree_auth_devise'
```

Then run `bundle install`. Authentication will then work exactly as it did in
previous versions of Spree.

This line is automatically added by the `spree install` command.

If you're installing this in a new Spree 1.2+ application, you'll need to install
and run the migrations with

```shell
bundle exec rake spree_auth:install:migrations
bundle exec rake db:migrate
```

change the following line in `config/initializers/spree.rb`
```ruby
Spree.user_class = 'Spree::LegacyUser'
```
to
```ruby
Spree.user_class = 'Spree::User'
```

In order to set up the admin user for the application you should then run:

```shell
bundle exec rake spree_auth:admin:create
```

Running Tests
-------------

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

Further Documentation
------------
Spree has a number of really useful guides online at [http://guides.spreecommerce.com](http://guides.spreecommerce.com).

Roadmap
------------
Spree roadmap at [https://trello.com/b/PQsUfCL0/spree-roadmap](https://trello.com/b/PQsUfCL0/spree-roadmap).

Contributing
------------

Spree is an open source project and we encourage contributions. Please review the
[contributing guidelines](http://guides.spreecommerce.com/developer/contributing.html)
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
-------

Spree is released under the [New BSD License](https://github.com/spree/spree/blob/master/license.md).
