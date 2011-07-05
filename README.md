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

    bundle install

Then use the install generator to do the basic setup

    rails g spree:site

Now you just need to run the new migrations, and setup some basic data

    rake db:migrate
    rake db:seed

If you also want some sample products, orders, etc. to play with you can run the appropriate rake task.

    rake spree_sample:load 


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

        rake sandbox

6. Start the server

        cd sandbox
        rails server

Running Tests
-------------

If you want to run all the tests across all the gems then

    $ cd spree
    $ rake spec     #=> 'this will run spec tests for all the gems'
    $ rake cucumber #=> 'this will run cucumber tests for all the gems'
    $ rake          #=> 'this will run both spec and cucumber tests for all the gems'

Each gem contains its own series of tests, and for each directory, you need to do a quick one-time
creation of a test application and then you can use it to run the tests.  For example, to run the
tests for the core project.

    $ cd core
    $ rake test_app
    $ rake spec
    $ rake cucumber
    $ rake          #=> 'this will run both spec and cucumber tests for the gem'

    # If you want to run specs for only a single spec file
    $ bundle exec rspec spec/models/state_spec.rb

    # If you want to run a particular line of spec
    $ bundle exec rspec spec/models/state_spec.rb:7

    # If you want to run a single cucumber feature
    # bundle exec cucumber features/admin/orders.feature --require features

    # If you want to run a particular scenario then include the line number
    # bundle exec cucumber features/admin/orders.feature:3 --require features


Contributing
------------

Spree is an open source project.  We encourage contributions.  Please see the [contributors guidelines](http://spreecommerce.com/documentation/contributing_to_spree.html) before contributing.
