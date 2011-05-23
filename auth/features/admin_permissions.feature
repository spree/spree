@custom_permissions
Feature: Admin Permissions

  Background: Admin is restricted from accessing orders
    Given I have an admin account of "admin@person.com/password"
    Given I do not have permission to access orders
    And I go to the sign in page
    And I sign in as "admin@person.com/password"

  Scenario: Admin tries to list the orders
    When I go to the admin orders page
    Then I should see "Authorization Failure"

  Scenario: Admin tries to edit the order
    Given an order exists with a number of "R123"
    When I go to the edit admin order page for "R123"
    Then I should see "Authorization Failure"

  Scenario: Admin tries to show the order
    Given an order exists with a number of "R123"
    When I go to the show admin order page for "R123"
    Then I should see "Authorization Failure"
