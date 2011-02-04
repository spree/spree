Feature: Admin visiting reports

  Scenario: Visiting admin reports page
    Given I go to the admin home page
    When I follow "Reports"
    When I follow "Sales Total"
    Then I should see "Sales Totals"
    Then I should see "Item Total"
    Then I should see "Adjustment Total"
    Then I should see "Sales Total"

  Scenario: search
    Given the custom orders exist for reports feature
    When I fill in "search_created_at_greater_than" with "2011/01/01"
    When I fill in "search_created_at_less_than" with "2011/12/31"
    When I press "Search"
    Then I should see "$300.00"
