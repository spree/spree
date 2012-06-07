Feature: Extension generator

  Scenario: Generating a model within an extension
    When I successfully run `spree extension brands`
    And I cd to "spree_brands"
    And I successfully run `pwd`
    And I successfully run `bundle exec rake test_app`
    And I successfully run `bundle exec rails g model spree/brands`
    Then a file named "app/models/spree.rb" should exist
    And a file named "app/models/spree/brands.rb" should exist
