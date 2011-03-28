Feature: Admin managing customer details

    @javascript
  Scenario: edit order
    Given a shipping method exists with a display on of "front_end"
    Given all orders are deleted
    Given all line items are deleted
    Given the following orders exist:
      |completed at         |
      |2011-02-01 12:36:15  |
      |2010-02-01 17:36:42  |
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
    When I click first link from selector "table td.actions a"
    When I follow "Customer Details"
    Then the "order_ship_address_attributes_firstname" field should contain "John 99"

    @javascript
  Scenario: edit order with validation error
    Given a shipping method exists with a display on of "front_end"
    Given all orders are deleted
    Given all line items are deleted
    Given the following orders exist:
      |completed at         |
      |2011-02-01 12:36:15  |
      |2010-02-01 17:36:42  |
    Given custom line items associated with products
    When I go to the admin home page
    When I click first link from selector "table td.actions a"
    When I follow "Customer Details"
    When I press "Continue"
    Then show me the page
    Then I should see "Ship address firstname can't be blank"
