Feature: Visiting products

  Background:
    Given the following taxonomies exist:
      | name        |
      | Brand       |
      | Categories  |
    Given the custom taxons and custom products exist

  Scenario: show page
    When I go to the home page
    When I click first link from selector "ul.product-listing a"
    Then I should see "$17.99"
    When I click first link from selector "form button.primary"
    Then I should see "Shopping Cart"

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
    When I check "Price_Range_Under_$10"
    When I press "Search" within "#sidebar_products_search"
    Then I should see "No products found"

  Scenario: select between 15 and 18
    When I go to the home page
    When I follow "Ruby on Rails"
    When I check "Price_Range_$15_-_$18"
    When I press "Search" within "#sidebar_products_search"
    Then verify products listing for price range search 15-18

  Scenario: select 18 and above
    When I go to the home page
    When I follow "Ruby on Rails"
    When I check "Price_Range_$18_-_$20"
    When I check "Price_Range_$20_or_over"
    When I press "Search" within "#sidebar_products_search"
    Then verify products listing for price range search 18 and above
