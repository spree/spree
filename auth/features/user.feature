Feature: admin changing email address

  Background:
    Given I have an admin account of "admin@person.com/password"
    When I go to the admin page
    And I should be on the login page
    Then I sign in as "admin@person.com/password"
    And I should see "Logged in successfully"
    And I should be on the admin page
    When I follow "Users"
    When I click first link from selector "table#listing_users td.user_email a"
    Then I should see "User Account"
    Then I should see "admin@person.com"
    Then I click first link from selector "a.edit_user"
    Then I should see "Editing User"

  Scenario: admin editing email with validation error
    When I fill in "user_email" with "a"
    When I press "Update"
    Then I should see "Email is invalid"

  Scenario: admin editing roles
    When I check "user_role_user"
    When I press "Update"
    Then I should see "User has been successfully updated!"
    When I click first link from selector "#content a.edit"
    Then the "user_role_user" checkbox should be checked

  Scenario: listing users when anonymous users are present
    Given an anonymous user has been created
    When I follow "Users"
    Then should not see "@example.net"

