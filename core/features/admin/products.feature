Feature: Admin visiting products

  Scenario: Visiting admin products page
    Given the following products exist:
      | name                |  available_on        |
      | apache baseball cap |  2011-01-06 18:21:13 |
      | zomg shirt          |  2011-01-06 18:21:13 |
    Given count_on_hand is 10 for all products
    And I go to the admin home page
    When I follow "Products"
    Then I should see listing products tabular attributes with name ascending
    When I follow "admin_products_listing_name_title"
    Then I should see listing products tabular attributes with name descending

  Scenario: Visiting admin products page search
    Given the following products exist:
      | name                 | sku  | available_on        |
      | apache baseball cap  | A100 | 2011-01-01 01:01:01 |
      | apache baseball cap2 | B100 | 2011-01-01 01:01:01 |
      | zomg shirt           | Z100 | 2011-01-01 01:01:01 |
    Given count_on_hand is 10 for all products
    When I go to the admin home page
    When I follow "Products"
    When I fill in "search_name_contains" with "ap"
    When I press "Search"
    Then I should see listing products tabular attributes with custom result 1
    When I fill in "search_variants_including_master_sku_contains" with "A1"
    When I press "Search"
    Then I should see listing products tabular attributes with custom result 2

  @javascript
  Scenario: admin products create
    Given I go to the admin home page
    When I follow "Products"
    When I follow "admin_new_product"
    Then async I should see "SKU" within "#new_product"
    When I fill in "product_name" with "Baseball Cap"
    When I fill in "product_sku" with "B100"
    When I fill in "product_price" with "100"
    When I fill in "product_available_on" with "2011/01/24"
    When I press "Create"
    Then I should see "Successfully created!"
    When I fill in "product_on_hand" with "100"
    When I press "Update"
    Then I should see "Successfully updated!"
    When I follow "Products"

  @javascript
  Scenario: admin products edit
    Given the following products exist:
      | name                 | sku  | available_on        |
      | apache baseball cap  | A100 | 2011-01-01 01:01:01 |
      | apache baseball cap2 | B100 | 2011-01-01 01:01:01 |
      | zomg shirt           | Z100 | 2011-01-01 01:01:01 |
    Given count_on_hand is 10 for all products
    When I go to the admin home page
    When I follow "Products"
    When I click on first link with class "admin_edit_product"
    When I fill in "product_name" with "apache baseball cap 99"
    When I press "Update"
    Then I should see "Successfully updated!"
