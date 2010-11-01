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

Then use the install generator to do the basic setup (add Spree to Gemfile, etc.)

    rails g spree:site

Now its time to install all of the necessary migrations, assets, etc.

    rake spree:install

If you'd like to also install sample data and images you can follow up the above command with:

    rake spree_sample:install

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

3. Create a sandbox rails application for testing purposes (and automatically perform all necessary database setup)

        rake sandbox

6. Start the server

        cd sandbox
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
app with what it needs to run (primarily migrations.)  So for the spree_auth gem, for example,
you would use the following

    rails g spree_auth:install


Contributing
------------

Spree is an open source project.  We encourage contributions.  Please see the [contributors guidelines](http://spreecommerce.com/documentation/contributing_to_spree.html) before contributing. 

The Github team has also been kind enough to write up some great [documentation](http://help.github.com/pull-requests/) on working with pull requests. Contributions should be performed on [topic branches](http://progit.org/book/ch3-4.html) in your personal forks - just issue your pull requests from there. We're also asking that you continue to log important issues for non-trivial patches in our [lighthouse repository](http://railsdog.lighthouseapp.com/projects/31096-spree). You can just link the pull request in the ticket (and link the ticket in the pull request.)
