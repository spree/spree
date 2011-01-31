Feature: Admin > configurations > analytics_tracker

  Scenario: Admin > configurations > analytics_tracker
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Analytics Tracker"
    Then I should see "Analytics Trackers"

  Scenario: admin updating analytics tracker
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Analytics Trackers"
    When I should see "Analytics Trackers"
    When I follow "admin_new_tracker_link"
    When I fill in "tracker_analytics_id" with "a100"
    When I press "Create"
    Then I should see "Successfully created!"
