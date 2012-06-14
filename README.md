SUMMARY
-------

Spree is a complete open source commerce solution for Ruby on Rails.  It was originally developed by Sean Schofield
and is now maintained by a dedicated [core team](http://spreecommerce.com/core-team).  You can find out more about
by visiting the [Spree e-commerce project page](http://spreecommerce.com).

Spree actually consists of several different gems, each of which are maintained in a single repository and documented
in a single set of [online documentation](http://spreecommerce.com/documentation).  By requiring the Spree gem you
automatically require all of the necessary dependency gems.  Those gems are as follows:

* spree_api
* spree_auth
* spree_cmd
* spree_core
* spree_dash
* spree_promo
* spree_sample

All of the gems are designed to work together to provide a fully functional e-commerce platform.  It is also possible,
however, to use only the pieces you are interested in.  So for example, you could use just the barebones spree\_core gem
and perhaps combine it with your own custom authorization scheme instead of using spree_auth.

[![Build Status](https://secure.travis-ci.org/spree/spree.png)](http://travis-ci.org/spree/spree)

Installation
------------

The fastest way to get started is by using the spree command line tool
available in the spree gem. It will add Spree to an existing Rails
application.
    $ gem install rails -v 3.1.6
    $ gem install spree -v 1.0.4
    $ rails new my_store
    $ spree install my_store

This will add the Spree gem, create initializers, copy migrations and
optionally generate sample products and orders.

If you get an "Unable to resolve dependencies" error when installing the Spree gem then you can try installing just the spree_cmd gem which should avoid any circular dependency issues.

    $ gem install spree_cmd

To auto accept all prompts while running the install generator, pass -A as an option

    $ spree install my_store -A

Using the Gem
-------------

You can manually add Spree to your Rails 3.x application. Add Spree to
your Gemfile.

    gem 'spree', '1.0.4'

Update your bundle

    $ bundle install

Use the install generator to copy migrations, initializers and generate
sample data.

    $ rails g spree:install

You can avoid running migrations or generating seed and sample data

    $ rails g spree:install --migrate=false --sample=false --seed=false

You can always perform the steps later.

    $ bundle exec rake db:migrate
    $ bundle exec rake db:seed

To manually load sample products, orders, etc., run the following rake task

    $ bundle exec rake spree_sample:load

Browse Store
------------

http://localhost:nnnn

Browse Admin Interface
----------------------

http://localhost:nnnn/admin



Working with the edge source (latest and greatest features)
-----------------------------------------------------------

The source code is essentially a collection of gems.  Spree is meant to be run within the context of Rails application.  You can easily create a sandbox application inside of your cloned source directory for testing purposes.


1. Clone the Git repo

        git clone git://github.com/spree/spree.git spree
        cd spree

2. Install the gem dependencies

        bundle install

3. Create a sandbox Rails application for testing purposes (and automatically perform all necessary database setup)

        bundle exec rake sandbox

6. Start the server

        cd sandbox
        rails server

Performance
-----------

You may noticed that your Spree store runs slowly in development mode.  This is a side-effect of how Rails works in development mode which is to continuous reload your Ruby objects on each request.  The introduction of the asset pipeline in Rails 3.1 made default performance in development mode significantly worse.  There are, however, a few tricks to speeding up performance in development mode.

You can recompile your assets as follows:

    $ bundle exec rake assets:precompile:nondigest

If you want to remove precompiled assets (recommended before you commit to Git and push your changes) use the following rake task:

    $ bundle exec rake assets:clean



Running Tests
-------------

If you want to run all the tests across all the gems then

    $ cd spree
    $ bundle exec rake

Each gem contains its own series of tests, and for each directory, you need to do a quick one-time
creation of a test application and then you can use it to run the tests.  For example, to run the
tests for the core project.

    $ cd core
    $ bundle exec rake test_app

If you're working on multiple facets of Spree, you may want
to run this command at the root of the Spree project to
generate test applications for all the facets:

    $ bundle exec rake test_app

You can run all of the tests inside a facet by also running
this command:

    $ cd core
    $ bundle exec rake

If you want to run specs for only a single spec file

    $ bundle exec rspec spec/models/state_spec.rb

If you want to run a particular line of spec

    $ bundle exec rspec spec/models/state_spec.rb:7


Contributing
------------

Spree is an open source project.  We encourage contributions.  Please see the [contributors guidelines](http://spreecommerce.com/documentation/contributing_to_spree.html) before contributing.
