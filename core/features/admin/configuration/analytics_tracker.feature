Feature: analytics tracker

  Scenario: index
    Given 2 trackers exist
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Analytics Tracker"
    Then I should see "Analytics Trackers"
    Then verify tabular data for tracker index


  Scenario: create
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Analytics Trackers"
    When I should see "Analytics Trackers"
    When I follow "admin_new_tracker_link"
    When I fill in "tracker_analytics_id" with "a100"
    When I press "Create"
    Then I should see "Successfully created!"
