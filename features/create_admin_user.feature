Feature: Create Admin User
  In order to manage products in the store
  As a first time user
  I should be able to create an admin account

  Scenario: No Admin User
    Given no users exist with the role: "admin"
    When I am on the home page
    Then I should see "Please create a user account"

  Scenario: Create Admin User
    Given no users exist with the role: "admin"
    When I am on the home page
    And I fill in "Email" with "email@person.com"
    And I fill in "Password" with "password"
    And I fill in "Confirm" with "password"
    And I press "Create"
    Then I should see "User created successfully"
