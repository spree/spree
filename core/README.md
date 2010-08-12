Testing
=======

Create a test site

    rails new sandbox -m spec/sandbox_template.rb -J -T

Switch to the test site and run the generator

    cd sandbox
    rails g spree_core:install

Run the migrations and prepare the test database

    rake db:migrate db:seed db:test:prepare

Run the tests

    rspec ../spec