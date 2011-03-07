Feature: Admin managing shipments

  @wip @stop @javascript
  Scenario: create new shipment
    Given all orders are deleted
    Given all line items are deleted
    Given the following orders exist:
      |completed at         | number  |
      |2011-02-01 12:36:15  | R100    |
    Given custom line items associated with products
    When I go to the admin home page
    When I click first link from selector "table td.actions a"
    When I follow "Customer Details"
    When I fill in "order_ship_address_attributes_firstname" with "John 99"
    When I fill in "order_ship_address_attributes_lastname" with "Doe"
    When I fill in "order_ship_address_attributes_address1" with "100 first lane"
    When I fill in "order_ship_address_attributes_address2" with "#101"
    When I fill in "order_ship_address_attributes_city" with "Bethesda"
    When I fill in "order_ship_address_attributes_zipcode" with "20170"
    When I select "Maryland" from "order_ship_address_attributes_state_id"
    When I fill in "order_ship_address_attributes_phone" with "123-456-7890"
    When I press "Continue"
    When I go to the admin home page
    When I follow the first admin_edit_order link
    When I follow "Customer Details"
    Then the "order_ship_address_attributes_firstname" field should contain "John 99"
    Given product is associated with order
    Given custom payment associated with order R100
    Given custom line items associated with products
    Given a shipping method exists
    And I go to the admin home page
    When I click first link from selector "table td.actions a"
    When I follow "Shipments"
    When I click first link from selector "#new_shipment_section a"
    Then show me the page
    Given custom inventory units associated with order R100
    When I press "Create"
    Then I should see ""
    Then show me the page



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


