Feature: Admin home page
  In order to do administrative work
  I should be able to login as an admin

  Scenario: Visiting admin home page
    Given 2 custom orders
    And I go to the admin home page
    Then I should see listing orders tabular attributes with completed_at descending
    When I follow "Order Date"
    Then I should see listing orders tabular attributes with completed_at ascending
    When I follow "Order"
    Then I should see listing orders tabular attributes with order number ascending
    When I follow "Order"
    Then I should see listing orders tabular attributes with order number descending


