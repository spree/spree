Feature: Admin visiting orders

  Scenario: Visiting orders page
    Given the following orders exist:
      |completed at         |
      |2011-02-01 12:36:15  |
      |2010-02-01 17:36:42  |
    And I go to the admin home page
    Then I should see listing orders tabular attributes with completed_at descending
    When I follow "Order Date"
    Then I should see listing orders tabular attributes with completed_at ascending
    When I follow "Order" within "#listing_orders"
    Then I should see listing orders tabular attributes with order number ascending

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
    #Then TODO select a product and follow the whole chain
