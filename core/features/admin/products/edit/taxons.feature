Feature: Admin editing products

    @javascript
  Scenario: admin managing taxons
    Given custom taxons exist
    Given the following products exist:
      | name                 | sku  | available_on        |
      | apache baseball cap  | A100 | 2011-01-01 01:01:01 |
      | apache baseball cap2 | B100 | 2011-01-01 01:01:01 |
      | zomg shirt           | Z100 | 2011-01-01 01:01:01 |
    Given count_on_hand is 10 for all products
    When I go to the admin home page
    When I follow "Products"
    When I click first link from selector "table#listing_products a.edit"
    When I follow "Taxons"
    Then I should see 2 tabular records with selector "#selected-taxons table.index"
    Then I should see row 1 and column 0 to have value "None." with selector "#selected-taxons table.index"
    When I fill in "searchtext" with "a"
    Then async
    Then I wait for 2 seconds
    Then verify admin taxons listing
    When I click first link from selector "#search_hits a.iconlink"
    Then I wait for 2 seconds
    When I follow "Taxons"
    Then I should see 2 tabular records with selector "#selected-taxons table.index"
    Then I should see row 1 and column 0 to have value "Brand" with selector "#selected-taxons table.index"
