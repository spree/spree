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
* spree_dashboard
* spree\_payment_gateway
* spree_promotions
* spree_sample

All of the gems are designed to work together to provide a fully functional e-commerce platform.  It is also possible,
however, to use only the pieces you are interested in.  So for example, you could use just the barebones spree\_core gem
and perhaps combine it with your own custom authorization scheme instead of using spree_auth.

Using the Gem
-------------

Start by adding the gem to your existing Rails 3.x application's Gemfile

    gem 'spree'

Then use the install generator to install all of the necessary migrations, assets, etc.

    rails g spree:install

*NOTE: This takes a while since its actually calling several generators (one for each of the dependencies) and
apparently Rails generators are quite slow.*

Now you just need to run the new migrations

    rake db:migrate
    rake db:seed

If you also want some sample products, orders, etc. to play with you can run the appropriate rake task.

    rake db:sample


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

        git clone git://github.com/railsdog/spree.git spree
        cd spree

2. Install the gem dependencies

        bundle install

3. Create a sanbox rails application for testing purposes

        rails new sandbox -m sample/sandbox_template.rb
        cd sandbox

4. Generate the necessary Spree files

        rails g spree:install

5. Bootstrap the database (run the migrations, create seed data, optionally load sample data.)

        rake db:migrate db:seed db:sample

6. Start the server

        rails server

Running Tests
-------------

Each gem contains its own series of tests, and for each directory, you need to do a quick one-time
creation of a test application and then you can use it to run the tests.  For example, to run the
tests for the core project.

    rails new testapp -m spec/test_template.rb -T -J
    cd testapp
    rails g spree_core:install
    rake db:migrate db:seed db:test:prepare

Then run the tests

    rspec spec

Note that each project has its own generator for "installing."  This basically sets up the test
app with what it needs to run (primarily migrations.)  So for the spree_auth gme, for example,
you would use the following

    rails g spree_auth:install


Contributing
------------

Spree is an open source project.  We encourage contributions.  Please see the [contributors guidelines](http://spreecommerce.com/documentation/contributing_to_spree.html) before contributing.  **Do not send a Github pull request - it will be ignored.**