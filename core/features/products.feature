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
    When I go to the home page
    When I follow "Ruby on Rails"
    Then verify products listing for Ruby on Rails brand

  Scenario: visit brand Ruby
    When I go to the home page
    When I follow "Ruby"
    Then verify products listing for Ruby brand

  Scenario: visit brand Apache
    When I go to the home page
    When I follow "Apache"
    Then verify products listing for Apache brand

  Scenario: visit category Clothing
    When I go to the home page
    When I follow "Clothing"
    Then verify products listing for Clothing category

  Scenario: visit category Mugs
    When I go to the home page
    When I follow "Mugs"
    Then verify products listing for Mugs category

  Scenario: visit category Bags
    When I go to the home page
    When I follow "Bags"
    Then verify products listing for Bags category

  Scenario: select under 10
    When I go to the home page
    When I follow "Ruby on Rails"
    Then show me the page

    When I check "Price_Range_Under_$10"
    When I press "Search" within "#sidebar_products_search"
    Then I should see "No products found"
