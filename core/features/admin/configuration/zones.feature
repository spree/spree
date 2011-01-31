Feature: Admin > configurations > zones

  Scenario: Visiting admin configurations zones
    When I follow "Configuration"
    Given 2 zones exist
    When I follow "Zones"
    Then I should see listing zones tabular attributes

  Scenario: admin updating zones
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Zones"
    When I follow "admin_new_zone_link"
    Then I should see "New Zone"
    When I fill in "zone_name" with "asian"
    When I fill in "zone_description" with "asian zone"
    When I press "Create"
    Then I should see "Successfully created!"
