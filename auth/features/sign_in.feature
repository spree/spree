Feature: Sign in
  In order to make a purchase
  A User
  Should be able to sign in

  Background:
    Given I am signed up as "email@person.com/secret"
    And I go to the sign in page

  Scenario: User is asked to sign in
    When I go to the admin page
    Then I should not see "Authorization Failure"

  Scenario: User signs in successfully
    Given I go to the home page
    And I sign in as "email@person.com/secret"
    Then I should see "Logged in successfully"
    Then I should be on the products page
    And I should be logged in

  Scenario: User is not signed up
    Given I sign in as "email@person.com/wrong_password"
    Then I should see "Invalid email or password"
    And I should be logged out

  Scenario: User enters wrong password
    Given I sign in as "email@person.com/wrongpassword"
    Then I should be on the sign in page
    And I should see "Invalid email or password"
    And I should be logged out

  Scenario: User requests a restricted page with the correct password
    Given I have an admin account of "admin@person.com/password"
    When I go to the admin page
    And I should be on the login page
    Then I sign in as "admin@person.com/password"
    And I should see "Logged in successfully"
    And I should be on the admin page

