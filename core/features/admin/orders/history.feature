Feature: Admin visiting history

    @javascript
  Scenario: edit order
    Given an order exists
    Given the order is finalized
    When I go to the admin home page
    When I follow the first admin_edit_spree_order link
    When I follow "History"
    Then I should see order history tabular attributes
