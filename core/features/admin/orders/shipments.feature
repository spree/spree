Feature: Admin managing shipments

  @wip @stop
  Scenario: create new shipment with validation error
    Given a shipping method exists
    Given the following orders exist:
      |completed at         | number |
      |2011-02-01 12:36:15  | R100   |
    Given product is associated with order
    Given custom payment associated with order R100
    And I go to the admin home page
    When I click first link from selector "table td.actions a"
    When I follow "Shipments"
    When I click first link from selector "#new_shipment_section a"
    When I press "Create"
    Then I should see "Address firstname can't be blank"


