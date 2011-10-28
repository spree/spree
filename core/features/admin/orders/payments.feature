Feature: Admin managing payments

  @javascript
  Scenario: payments list
    Given the following orders exist:
      |completed at         | number | state    |
      |2011-02-01 12:36:15  | R100   | complete |
    Given product is associated with order
    Given custom payment associated with order R100
    And I go to the admin home page
    When I click first link from selector "table td.actions a"
    When I follow "Payments"
    Then I should see "Payment: balance due" within "#payment_status"
    Then verify data from "table.index" with following tabular values:
      | Date/Time | Amount  | Payment Method | Payment State | Actions |
      | ignore    | $39.98  | Credit Card    | pending       | ignore  |
    When I press "Void"
    Then I should see "Payment: balance due" within "#payment_status"
    Then I should see "Payment Updated"
    Then verify data from "table.index" with following tabular values:
      | Date/Time | Amount | Payment Method | Payment State | Actions |
      | ignore    | $39.98 | Credit Card    | void          | ignore  |
    When I click first link from selector "#new_payment_section a"
    Then I should see "New Payment"
    When I press "Update"
    When I press "Capture"
    Then I should see "Payment: paid" within "#payment_status"
    Then I should not see "#new_payment_section"
    When I follow "Shipments"
    Given a custom shipping method exists
    Given custom order has a ship address
    When I click first link from selector "#new_shipment_section a"
    When I check first element with class "inventory_unit"
    When I press "Create"
    Then I should see "successfully created!"
    When I follow "Shipments"
    Then verify data from "table.index" with following tabular values:
      | Shipment # | Shipping Method | Cost   | Tracking | Status  | Date/Time | Action |
      | ignore     | UPS Ground      | $10.00 | ignore   | Pending | ignore    | ignore |
    When I click first link from selector "#new_shipment_section a"
    When I check first element with class "inventory_unit"
    When I press "Create"
    Then I should see "successfully created!"
    When I follow "Shipments"
    Then verify data from "table.index" with following tabular values:
      | Shipment # | Shipping Method | Cost   | Tracking | Status  | Date/Time | Action |
      | ignore     | UPS Ground      | $10.00 | ignore   | Pending | ignore    | ignore |
      | ignore     | UPS Ground      | $10.00 | ignore   | Pending | ignore    | ignore |

  @javascript
  Scenario: payments list with history
    Given the following orders exist:
      |completed at         | number | state    |
      |2011-02-01 12:36:14  | R100   | complete |
    Given a completed order
    And I go to the admin home page
    When I follow the first admin_edit_spree_order link
    When I follow "Payments"
    Then I should see "Payment: balance due" within "#payment_status"
    When I press "Capture"
    Then I should see "Payment: paid" within "#payment_status"
    Then I should not see "#new_payment_section"
    When I follow "Shipments"
    Given a custom shipping method exists
    Given custom order has a ship address
    When I click first link from selector "#new_shipment_section a"
    When I check first element with class "inventory_unit"
    When I press "Create"
    Then I should see "successfully created!"
    When I follow "Shipments"
    When I click first link from selector "#new_shipment_section a"
    When I check first element with class "inventory_unit"
    When I press "Create"
    Then I should see "successfully created!"
    When I follow "Shipments"
    When I follow "History"
    Then verify data from "table.index" with following tabular values:
      | Event    | From State  | To State    | User   | Date/Time |
      | Payment  | paid        | balance due | ignore | ignore    |
      | Shipment | pending     | backorder   | ignore | ignore    |
      | Payment  | balance due | paid        | ignore | ignore    |
      | Payment  | paid        | balance due | ignore | ignore    |


