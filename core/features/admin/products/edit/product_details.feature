Feature: Admin editing products

  Scenario: admin editing a product
    Given the following products exist:
      | name                 | sku  | available_on        |
      | apache baseball cap  | A100 | 2011-01-01 01:01:01 |
      | apache baseball cap2 | B100 | 2011-01-01 01:01:01 |
      | zomg shirt           | Z100 | 2011-01-01 01:01:01 |
    Given count_on_hand is 10 for all products
    When I go to the admin home page
    When I follow "Products"
    When I click first link from selector "table#listing_products a.edit"
    When I fill in "product_name" with "apache baseball cap 99"
    When I press "Update"
    Then I should see "successfully updated!"

