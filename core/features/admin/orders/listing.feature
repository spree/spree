Feature: Admin visiting orders listing

  Scenario: orders listing
    Given the following orders exist:
      |created at           | number |
      |2011-02-01 12:36:15  | R100   |
      |2011-02-01 12:36:15  | R200   |
    And I go to the admin home page
    Then I should see row 1 and column 2 to have value "cart" with selector "table#listing_orders"
    Then I should see row 1 and column 1 to have value "R100" with selector "table#listing_orders"

  Scenario: orders listing with sorting
    Given the following orders exist:
      |created at           | number |
      |2011-02-01 12:36:15  | R100   |
      |2010-02-01 17:36:42  | R200   |
    And I go to the admin home page
    Then I should see listing orders tabular attributes with created_at descending
    When I follow "Order Date"
    Then I should see listing orders tabular attributes with created_at ascending
    When I follow "Order" within "#listing_orders"
    Then I should see listing orders tabular attributes with order number ascending

  Scenario: orders search
    Given the following orders exist:
      |created at           | number |
      |2011-02-01 12:36:15  | R100   |
      |2011-02-01 12:36:15  | R200   |
    And I go to the admin home page
    When I fill in "search_number_like" with "R200"
    When I press "Search"
    Then I should see row 1 and column 1 to have value "R200" with selector "table#listing_orders"

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
