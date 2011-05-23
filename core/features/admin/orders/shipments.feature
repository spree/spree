Feature: Admin managing shipments

  Scenario: create new shipment
    Given all orders are deleted
    Given all line items are deleted
    Given the following orders exist:
      |completed at         | number  |
      |2011-02-01 12:36:15  | R100    |
    Given custom line items associated with products
    Given custom order has a ship address
    Given product is associated with order
    Given custom payment associated with order R100
    Given custom line items associated with products
    Given a shipping method exists
    And I go to the admin home page
    When I click first link from selector "table td.actions a"
    When I follow "Shipments"
    When I click first link from selector "#new_shipment_section a"
    Given custom inventory units associated with order R100
    When I press "Create"



  Scenario: create new shipment with validation error
    Given a shipping method exists
    Given the following orders exist:
      |completed at         | number |
      |2011-02-01 12:36:15  | R100   |
    Given product is associated with order
    Given custom payment associated with order R100
    And I go to the admin home page
    When I click first link from selector "table td.actions a"
    When I follow "Shipments"
    When I click first link from selector "#new_shipment_section a"
    When I press "Create"
    Then I should see "Address firstname can't be blank"


