Feature: Extension generator

  Background:
    When I successfully run `spree extension brands`
    And I cd to "spree_brands"
    And I successfully run `unset BUNDLE_GEMFILE`
    And I successfully run `bundle install`

  Scenario: Generating a model within an extension, then installing migrations

    And I successfully run `bundle exec rails g model spree/brands`
    Then a file named "app/models/spree.rb" should exist
    And a file named "app/models/spree/brands.rb" should exist
    And I successfully run `bundle exec rake test_app`
    And I cd to "spec/dummy"
    And I successfully run `ls db/migrate`
    And the output should contain "create_spree_brands"
