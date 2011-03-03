Feature: Admin managing payments

  Scenario: payments list
    Given the following orders exist:
      |completed at         | number |
      |2011-02-01 12:36:15  | R100   |
    Given custom payment associated with order R100
    And I go to the admin home page
    When I click first link from selector "table td.actions a"
    When I follow "Payments"
