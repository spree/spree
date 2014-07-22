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

[![Code Climate](https://codeclimate.com/github/spree/spree.png)](https://codeclimate.com/github/spree/spree)

Installation
------------

**THIS README IS FOR THE MASTER BRANCH OF SPREE AND REFLECTS THE WORK CURRENTLY
EXISTING ON THE MASTER BRANCH. IF YOU ARE WISHING TO USE A NON-MASTER BRANCH OF
SPREE, PLEASE CONSULT THAT BRANCH'S README AND NOT THIS ONE.**

The fastest way to get started is by using the spree command line tool
available in the spree gem which will add Spree to an existing Rails application.

```shell
gem install rails -v 4.1.2
gem install spree
rails _4.1.2_ new my_store
spree install my_store
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

Using stable builds and bleeding edge
-------------

To use a stable build of Spree, you can manually add Spree to your
Rails 4.1.x application. To use the 2-3-stable branch of Spree, add this line to
your Gemfile.

```ruby
gem 'spree', github: 'spree/spree', branch: '2-3-stable'
```

Alternatively, if you want to use the bleeding edge version of Spree, use this
line:

```ruby
gem 'spree', github: 'spree/spree'
```

**Note: The master branch is not guaranteed to ever be in a fully functioning
state. It is unwise to use this branch in a production system you care deeply
about.**

If you wish to have authentication included also, you will need to add the
`spree_auth_devise` gem as well. Either this:

```ruby
gem 'spree_auth_devise', github: 'spree/spree_auth_devise', branch: '2-3-stable'
```

Or this:

```ruby
gem 'spree_auth_devise', github: 'spree/spree_auth_devise'
```

Once you've done that, then you can install these gems using this command:

```shell
bundle install
```

Use the install generator to set up Spree:

```shell
rails g spree:install --sample=false --seed=false
```

At this point, if you are using spree_auth_devise you will need to change this
line in `config/initializers/spree.rb`:

```ruby
Spree.user_class = "Spree::LegacyUser"
```

To this:

```ruby
Spree.user_class = "Spree::User"
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

You can precompile your assets as follows:

```shell
bundle exec rake assets:precompile:nondigest
```

If you want to remove precompiled assets (recommended before you commit to Git
and push your changes) use the following rake task:

```shell
bundle exec rake assets:clean
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

[![Team City](http://www.jetbrains.com/img/logos/logo_teamcity_small.gif)](http://www.jetbrains.com/teamcity)

We use [TeamCity](http://www.jetbrains.com/teamcity/) to run the tests for Spree.

You can see the build statuses at [http://ci.spree.fm](http://ci.spree.fm/guestLogin.html?guest=1).

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
bundle exec rspec spec/models/state_spec.rb
```

If you want to run a particular line of spec
```shell
bundle exec rspec spec/models/state_spec.rb:7
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

Spree is an open source project and we encourage contributions. Please see the
[contributors guidelines](http://spreecommerce.com/documentation/contributing_to_spree.html)
before contributing.
