mrh/spree
---------

Spree is a complete open source e-commerce solution built with Ruby on Rails. It
was originally developed by Sean Schofield and is now maintained here.

Spree consists of several different gems, which are maintained in a single repository.

* spree_api (RESTful API)
* spree_frontend (User-facing components)
* spree_backend (Admin area)
* spree_core (Models & Mailers, the basic components of Spree that it can't run without)

Installation
------------

Add the following to your Gemfile

```ruby
group :spree, :default do
  gem 'spree', '= 2.4.11.beta', git: 'https://github.com/MountainRoseHerbs/spree.git', branch: 'master'
end
```

```shell
bundle install
bundle exec rails new my_store
```

Than follow the Rails [Engines documentation](http://guides.rubyonrails.org/engines.html#hooking-into-an-application)
on howto use the `spree` engine in your application.


Running Tests
-------------

Run the CI suite locally, assumes set-up postgresql.

```shell
./build-ci.rb
```

Dedicated tests for each subproject

```shell
cd subproject # example "core"
bundle install
bundle exec rake test_app
bundle exec rspec spec
```
