Feature: Account
  In order to edit my account
  As a user of different roles
  I want to be able to navigate to my account page

  Scenario: Admin user account editing
    Given I have an admin account of "admin@person.com/password"
    And I go to the sign in page
    When I sign in as "admin@person.com/password"
    And I follow "My Account"
    Then I should see "admin@person.com"

  Scenario: New user account editing
    When I go to the sign up page
    And I fill in "Email" with "email@person.com"
    And I fill in "Password" with "password"
    And I fill in "Password Confirmation" with "password"
    And I press "Create"
    When I follow "My Account"
    Then I should see "email@person.com"

  Scenario: existing user account editing
    Given the following user exists:
      | email            | password | password_confirmation |
      | email@person.com | secret   | secret                |
    And I go to the sign in page
    When I sign in as "email@person.com/secret"
    And I follow "My Account"
    Then I should see "email@person.com"








