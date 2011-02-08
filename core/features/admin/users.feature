

Feature: Admin visiting users

  Scenario: Visiting admin users page
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
    #Then I follow "a@example.com" #=> FIXME undefined method `roles' for #<User:0x102d87ce8> (ActionView::Template::Error)

  Scenario: admin users page search
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

  Scenario: admin users edit functionality
    Given I go to the admin home page
    Given existing user records are deleted
    Given the following users exist:
     | email          |
     | a@example.com  |
     | b@example.com  |
    When I follow "Users"
    #When I follow custom admin edit user link #=> FIXME undefined method `has_role?' for #<User:0x10317a440> (ActionView::Template::Error)

