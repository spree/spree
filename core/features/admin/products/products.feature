Feature: Admin visiting products

  Scenario: admin visiting products listing
    Given the following products exist:
      | name                |  available_on        |  count_on_hand  |
      | apache baseball cap |  2011-01-06 18:21:13 |  0              |
      | zomg shirt          |  2125-01-06 18:21:13 |  5              |
    And I go to the admin home page
    When I follow "Products"
    Then I should see listing products tabular attributes with name ascending
    When I follow "admin_products_listing_name_title"
    Then I should see listing products tabular attributes with name descending
  
  @selenium
  Scenario: admin using search on products listing (show deleted)
    Given the following products exist:
      | name                |  available_on        |  deleted_at          |
      | apache baseball cap |  2011-01-06 18:21:13 |  2011-01-06 18:21:13 |
      | zomg shirt          |  2111-01-06 18:21:13 |  nil                 |
    Given count_on_hand is 10 for all products  
    And I go to the admin home page
    When I follow "Products"
    Then I should see "zomg shirt"
    And  I should not see "apache baseball cap"
    When I check "Show Deleted"
    And press "Search"
    Then I should see "zomg shirt"
    And  I should see "apache baseball cap"
    When I uncheck "Show Deleted"
    And press "Search"
    Then I should see "zomg shirt"
    And  I should not see "apache baseball cap"
    
  Scenario: admin using search on products listing
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
  Scenario: admin creating a new product
    Given I go to the admin home page
    When I follow "Products"
    When I follow "admin_new_product"
    Then async I should see "SKU" within "#new_product"
    When I fill in "product_name" with "Baseball Cap"
    When I fill in "product_sku" with "B100"
    When I fill in "product_price" with "100"
    When I fill in "product_available_on" with "2011/01/24"
    When I press "Create"
    Then I should see "successfully created!"
    When I fill in "product_on_hand" with "100"
    When I press "Update"
    Then I should see "successfully updated!"

  @javascript
  Scenario: admin creating a new product with validation error
    Given I go to the admin home page
    When I follow "Products"
    When I follow "admin_new_product"
    Then async I should see "SKU" within "#new_product"
    When I press "Create"
    Then I should see "Name can't be blank"
    Then I should see "Price can't be blank"

  Scenario: admin cloning a product
    Given the following products exist:
      | name                 | sku  | available_on        |
      | apache baseball cap  | A100 | 2011-01-01 01:01:01 |
      | apache baseball cap2 | B100 | 2011-01-01 01:01:01 |
      | zomg shirt           | Z100 | 2011-01-01 01:01:01 |
    Given count_on_hand is 10 for all products
    When I go to the admin home page
    When I follow "Products"
    When I click first link from selector "table#listing_products a.clone"
    Then I should see "Product has been cloned"

  Scenario: admin uploading and then editing an image for a product
    Given the following products exist:
      | name                 | sku  | available_on        |
      | apache baseball cap  | A100 | 2011-01-01 01:01:01 |
      | apache baseball cap2 | B100 | 2011-01-01 01:01:01 |
      | zomg shirt           | Z100 | 2011-01-01 01:01:01 |
    Given count_on_hand is 10 for all products
    When I go to the admin home page
    When I follow "Products"
    When I click first link from selector "table#listing_products a.edit"
    When I follow "Images"
    When I follow "new_image_link"
    When I attach file "ror_ringer.jpeg" to "image_attachment"
    When I press "Update"
    Then I should see "successfully created!"
    When I click first link from selector "table.index a.edit"
    When I fill in "image_alt" with "ruby on rails t-shirt"
    When I press "Update"
    Then I should see "successfully updated!"
    Then I should see "ruby on rails t-shirt"

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
    When I fill in "searchtext" with "a"
    Then async
    Then I wait for 2 seconds
    Then verify admin taxons listing
    When I click first link from selector "#search_hits a"
    Then async
