Testing
=======

Create a test site

    rails new sandbox -m spec/sandbox_template.rb -J -T

Switch to the test site and run the generator(s)

    cd sandbox
    rails g spree_core:install
    rails g spree_auth:install

Run the migrations and prepare the test database

    rake db:migrate db:seed db:test:prepare

Run the tests

    rspec ../spec

Misc
====

authentication by token example

    http://localhost:3000/?auth_token=oWBSN16k6dWx46TtSGcp