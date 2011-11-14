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
* spree_core
* spree_dash
* spree_promo
* spree_sample

All of the gems are designed to work together to provide a fully functional e-commerce platform.  It is also possible,
however, to use only the pieces you are interested in.  So for example, you could use just the barebones spree\_core gem
and perhaps combine it with your own custom authorization scheme instead of using spree_auth.

Using the Gem
-------------

Start by adding the gem to your existing Rails 3.x application's Gemfile

    gem 'spree'

Update your bundle

    $ bundle install

Use the install generator to do the basic setup. The install generator will prompt you to run migrations, setup some
basic data, and load sample products, orders, etc.

    $ rails g spree:site

To auto accept all prompts while running the install generator, pass -A as an option

	$ rails g spree:site -A

If you chose to ignore the prompts while running the basic install
generator you can manually run migrations and load basic data with the following
commands

    $ bundle exec rake db:migrate
    $ bundle exec rake db:seed

To manually load sample products, orders, etc., run the following rake task

    $ bundle exec rake spree_sample:load

Peformance
----------

Rails 3.1 introduced a concept known as the asset pipeline.  Unfortunately it results in poor performance when running your site in development mode (production mode is unaffected.)  You may want to run the following command when testing locally in development mode

    $ bundle exec rake assets:precompile:nondigest

Using the precompile rake task in development will prevent any changes to asset files from being automatically included in when you reload the page. You must re-run the precompile task for changes to become available.

Browse Store
------------

http://localhost:nnnn

Browse Admin Interface
----------------------

http://localhost:nnnn/admin



Working with the edge source (latest and greatest features)
-----------------------------------------------------------

The source code is essentially a collection of gems.  Spree is meant to be run within the context of Rails application.  You can easily create a sandbox application inside of your cloned source directory for testing purposes.


1. Clone the git repo

        git clone git://github.com/spree/spree.git spree
        cd spree

2. Install the gem dependencies

        bundle install

3. Create a sandbox rails application for testing purposes (and automatically perform all necessary database setup)

        bundle exec rake sandbox

6. Start the server

        cd sandbox
        rails server

Performance
-----------

You may noticed that your Spree store runs slowly in development mode.  This is a side-effect of how Rails works in development mode which is to continuous reload your Ruby objects on each request.  The introduction of the asset pipeline in Rails 3.1 made default performance in development mode significantly worse.  There are, however, a few tricks to speeding up performance.

You can recompile your assets as follows:

        $ bundle exec rake assets:precompile RAILS_ENV=development

If you want to remove precompiled assets (recommended before you commit to git and push your changes) use the following rake task:

        $ bundle exec rake assets:clean



Running Tests
-------------

If you want to run all the tests across all the gems then

    $ cd spree
    $ bundle exec rake          #=> 'this will run both spec and cucumber tests for all the gems'

Each gem contains its own series of tests, and for each directory, you need to do a quick one-time
creation of a test application and then you can use it to run the tests.  For example, to run the
tests for the core project.

    $ cd core
    $ bundle exec rake test_app

Now you can run just the specs, just the features or everything together

    $ bundle exec rake spec
    $ bundle exec rake cucumber
    $ bundle exec rake          #=> 'this will run both spec and cucumber tests for the gem'

If you want to run specs for only a single spec file

    $ bundle exec rspec spec/models/state_spec.rb

If you want to run a particular line of spec

    $ bundle exec rspec spec/models/state_spec.rb:7

If you want to run a single cucumber feature

    $ bundle exec cucumber features/admin/orders.feature --require features

If you want to run a particular scenario then include the line number

    $ bundle exec cucumber features/admin/orders.feature:3 --require features


Contributing
------------

Spree is an open source project.  We encourage contributions.  Please see the [contributors guidelines](http://spreecommerce.com/documentation/contributing_to_spree.html) before contributing.
