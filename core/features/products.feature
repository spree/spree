Feature: Visiting products

  Background:
    Given the following taxonomies exist:
      | name        |
      | Brand       |
      | Categories  |
    Given the custom taxons and custom products exist

  Scenario: visit products page
    When I go to the home page
    When I fill in "keywords" with "shirt"
    When I press "Search"
    Then verify products listing for top search result

  Scenario: visit brand Ruby on Rails
    And I go to the home page
    When I follow "Ruby on Rails"
    Then verify products listing for Ruby on Rails brand

  Scenario: visit brand Ruby
    And I go to the home page
    When I follow "Ruby"
    Then verify products listing for Ruby brand

  Scenario: visit brand Apache
    And I go to the home page
    When I follow "Apache"
    Then show me the page
    Then verify products listing for Apache brand
