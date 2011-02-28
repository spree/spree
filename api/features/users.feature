Feature: admin managing api key

  Scenario: admin clearing and regenerating api key
    Given I have an admin account of "admin@person.com/password"
    When I go to the admin page
    And I should be on the login page
    Then I sign in as "admin@person.com/password"
    And I should see "Logged in successfully"
    And I should be on the admin page
    When I follow "Users"
    When I click first link from selector "table#listing_users a.edit"
    Then I should see "Editing User"
    When I press "Clear API key"
    Then I should see "No key defined"
    When I press "Generate API key"
    Then I should see "API key generated"
    When I press "Clear API key"
    Then I should see "API key cleared"

