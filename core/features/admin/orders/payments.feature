Feature: Admin managing payments

  @wip @stop
  Scenario: payments list
    Given the following orders exist:
      |completed at         | number |
      |2011-02-01 12:36:15  | R100   |
    Given product is associated with order
    Given custom payment associated with order R100
    And I go to the admin home page
    When I click first link from selector "table td.actions a"
    When I follow "Payments"
    Then I should see "Payment: balance due" within "#payment_status"
    Then verify data from "table.index" with following tabular values:
      | Date/Time | Amount  | Payment Method | Payment State | Actions |
      | ignore    | $199.90 | Credit Card    | pending       | ignore  |
    When I press "Void"
    Then I should see "Payment: balance due" within "#payment_status"
    Then I should see "Payment Updated"
    Then verify data from "table.index" with following tabular values:
      | Date/Time | Amount  | Payment Method | Payment State | Actions |
      | ignore    | $199.90 | Credit Card    | void          | ignore  |
    When I click first link from selector "#new_payment_section a"
    Then I should see "New Payment"
    When I press "Continue"
    When I press "Capture"
    Then I should see "Payment: paid" within "#payment_status"
    Then I should not see "#new_payment_section"
    When I follow "History"
    Then I should see "History"
    Then verify data from "table.index" with following tabular values:
      | Event   | From State  | To State | User   | Date/Time |
      | Payment | balance due | paid     | ignore | ignore    |
    When I follow "Shipments"
    Given a shipping method exists
    Given custom next on order
    Given custom order has a ship address
    When I click first link from selector "#new_shipment_section a"
    Then show me the page
    Then I should see "xx"


