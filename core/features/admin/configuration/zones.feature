Feature: Admin > configurations > zones

  Scenario: admin visiting zones listing
    Given I go to the admin home page
    When I follow "Configuration"
    Given all zones are deleted
    Given the following zones exist:
      | name    | description       |
      | eastern | zone is eastern  |
      | western | cool san franciso |
    When I follow "Zones"
    Then I should see listing zones tabular attributes with name asc
    When I follow "zones_order_by_description_title"
    Then I should see listing zones tabular attributes with description asc

  Scenario: admin creating new zone
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Zones"
    When I follow "admin_new_zone_link"
    Then I should see "New Zone"
    When I fill in "zone_name" with "asian"
    When I fill in "zone_description" with "asian zone"
    When I press "Create"
    Then I should see "successfully created!"
