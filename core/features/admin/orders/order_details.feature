Feature: Admin managing order details

  Scenario: edit order page with product information
    Given the following orders exist:
      |completed at         | number |
      |2011-02-01 12:36:15  | R100   |
    Given product is associated with order
    And I go to the admin home page
    When I follow "Orders"
    When I click first link from selector "table td.actions a"
    Then I should see "spree t-shirt"
    Then I should see "$199.90"



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
