Feature: Admin > configurations > states

  Scenario: admin visiting states listing
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "States"
    Then I should see listing states tabular attributes

    @javascript
  Scenario: admin creating a new state and then editing it
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "States"
    When I select "Canada" from "country"
    Then async
    When I follow "new_state"
    When I fill in "state_name" with "Calgary"
    When I fill in "Abbreviation" with "CL"
    When I press "Create"
    Then I should see "successfully created!"
    Then I should see "Calgary"
    When I click first link from selector "table#listing_states td.actions a.edit"
    Then I should see "Editing State"
    Then the "state_name" field should contain "Calgary"
    When I follow "States"
    When I select "Canada" from "country"
    Then async
    Then I should see "Calgary"

    @javascript
  Scenario: admin creating a new state with validation error
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "States"
    When I select "Canada" from "country"
    Then async
    When I follow "new_state"
    When I fill in "state_name" with ""
    When I fill in "Abbreviation" with ""
    When I press "Create"
    Then I should see "Name can't be blank"

