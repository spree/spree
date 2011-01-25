Feature: Admin visiting orders

  Scenario: Visiting orders page
    Given 2 custom orders
    And I go to the admin home page
    Then I should see listing orders tabular attributes with completed_at descending
    When I follow "Order Date"
    Then I should see listing orders tabular attributes with completed_at ascending
    When I follow "Order" within "#listing_orders"
    Then I should see listing orders tabular attributes with order number ascending

  Scenario: creating new order
    Given 2 custom orders
    And I go to the admin home page
    When I follow "Orders"
    Given a product exists with a sku of "a100"
    When I follow "admin_new_order"
    Then I should see "Add Product" within "#add-line-item"
