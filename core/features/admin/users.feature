Feature: Admin visiting users

  Scenario: Visiting admin users page
    Given I go to the admin home page
    Given existing user records are deleted
    Given the following users exist:
     | email          |
     | a@example.com |
     | b@example.com |
    When I follow "Users"
    Then I should see "Listing Users"
    When I follow "users_email_title"
    Then I should see listing users tabular attributes with order email asc
    When I follow "users_email_title"
    Then I should see listing users tabular attributes with order email desc
    When I fill in "search_email_contains" with "a@example.com"
    And I press "Search"
    Then I should see listing users tabular attributes for search result case
