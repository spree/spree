Feature: Admin visiting users

  Scenario: users index page with sorting
    Given I go to the admin home page
    Given existing user records are deleted
    Given the following users exist:
     | email          |
     | a@example.com  |
     | b@example.com  |
    When I follow "Users"
    Then I should see "Listing Users"
    When I follow "users_email_title"
    Then I should see listing users tabular attributes with order email asc
    When I follow "users_email_title"
    Then I should see listing users tabular attributes with order email desc

  Scenario: search
    Given I go to the admin home page
    Given existing user records are deleted
    Given the following users exist:
     | email          |
     | a@example.com  |
     | b@example.com  |
    When I follow "Users"
    When I fill in "search_email_contains" with "a@example.com"
    And I press "Search"
    Then I should see listing users tabular attributes for search result case

  Scenario: users show page
    Given I go to the admin home page
    Given existing user records are deleted
    Given the following users exist:
     | email          |
     | a@example.com  |
     | b@example.com  |
    When I follow "Users"
    When I click first link from selector "table#listing_users td.user_email a"
    Then I should see "User Account"
    Then I should see "a@example.com"
    Then I click first link from selector "a.edit_user"
    Then I should see "Editing User"

  Scenario: edit user email
    Given I go to the admin home page
    Given existing user records are deleted
    Given the following users exist:
     | email          |
     | a@example.com  |
     | b@example.com  |
    When I follow "Users"
    When I click first link from selector "table#listing_users td.user_email a"
    Then I should see "User Account"
    Then I should see "a@example.com"
    Then I click first link from selector "a.edit_user"
    Then I should see "Editing User"
    When I fill in "user_email" with "a@example.com99"
    When I press "Update"
    Then I should see "successfully updated!"
    Then I should see "a@example.com99"

  Scenario: edit user password
    Given I go to the admin home page
    Given existing user records are deleted
    Given the following users exist:
     | email          |
     | a@example.com  |
     | b@example.com  |
    When I follow "Users"
    When I click first link from selector "table#listing_users td.user_email a"
    Then I should see "User Account"
    Then I should see "a@example.com"
    Then I click first link from selector "a.edit_user"
    Then I should see "Editing User"
    When I fill in "user_password" with "welcome"
    When I fill in "user_password_confirmation" with "welcome"
    When I press "Update"
    Then I should see "successfully updated!"
