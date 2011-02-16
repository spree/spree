Feature: Admin visiting orders

    @javascript
  Scenario: edit order
    Given all orders are deleted
    Given all line items are deleted
    Given the following orders exist:
      |completed at         |
      |2011-02-01 12:36:15  |
      |2010-02-01 17:36:42  |
    Given custom line items associated with products
    When I go to the admin home page
    When I follow the first admin_edit_order link
    Then I should see "Total: $10.00"
    When I fill in "order_line_items_attributes_0_quantity" with "2"
    Then async I should see "Total: $20.00"
    When I press "Continue"
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
