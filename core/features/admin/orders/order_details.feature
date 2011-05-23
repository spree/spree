Feature: Admin visiting orders

  Scenario: Visiting orders details page
    Given the following orders exist:
      |created at           |
      |2011-02-01 12:36:15  |
      |2010-02-01 17:36:42  |
    And I go to the admin home page
    Then I should see listing orders tabular attributes with created_at descending
    When I follow "Order Date"
    Then I should see listing orders tabular attributes with created_at ascending
    When I follow "Order" within "#listing_orders"
    Then I should see listing orders tabular attributes with order number ascending

  Scenario: Search orders with only completed at input
    Given the following orders exist:
      |created at           | number |
      |2011-02-01 12:36:15  | R100   |
      |2010-02-01 17:36:42  | R200   |
    And I go to the admin home page
    When I fill in "search_created_at_greater_than" with "2011/01/01"
    And I press "Search"
    Then I should see listing orders tabular attributes with search result 1

  Scenario: Search orders with completed at and first name
    Given the following orders exist:
      |created at           | number |
      |2011-02-01 12:36:15  | R100   |
      |2011-02-01 12:36:15  | R101   |
      |2010-02-01 17:36:42  | R200   |
    Given the custom address exists for the given orders
    And I go to the admin home page
    When I fill in "search_created_at_greater_than" with "2011/01/01"
    When I fill in "search_bill_address_firstname_starts_with" with "joh"
    And I press "Search"
    Then I should see listing orders tabular attributes with search result 2

  Scenario: creating new order
    Given the following orders exist:
      |completed at         |
      |2011-02-01 12:36:15  |
      |2010-02-01 17:36:42  |
    And I go to the admin home page
    When I follow "Orders"
    Given a product exists with a sku of "a100"
    When I follow "admin_new_order"
    Then I should see "Add Product" within "#add-line-item"
    #Then FIXME TODO select a product and follow the whole chain

    @javascript
  Scenario: edit order page with product information
    Given the following orders exist:
      |completed at         | number |
      |2011-02-01 12:36:15  | R100   |
    Given product is associated with order
    And I go to the admin home page
    When I follow "Orders"
    When I click first link from selector "table td.actions a"
    Then I should see "spree t-shirt"
    Then I should see "$39.98"
    When I fill in "order_line_items_attributes_0_quantity" with "1"
    Then async I should see "Total: $19.99"

  Scenario: new order page comes up
    Given the following orders exist:
      |completed at         |
      |2011-02-01 12:36:15  |
      |2010-02-01 17:36:42  |
    And I go to the admin home page
    When I follow "Orders"
    Given a product exists with a sku of "a100"
    When I follow "admin_new_order"
    Then I should see "Add Product" within "#add-line-item"

