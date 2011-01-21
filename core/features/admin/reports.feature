Feature: Admin visiting reports

  Scenario: Visiting admin reports page
    Given I go to the admin home page
    When I follow "Reports"
    When I follow "Sales Total"
    Then I should see "Sales Totals"
    Then I should see "Item Total"
    Then I should see "Adjustment Total"
    Then I should see "Sales Total"
