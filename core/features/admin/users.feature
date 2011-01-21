Feature: Admin visiting users

  Scenario: Visiting admin users page
    Given I go to the admin home page
    When I follow "Users"
    Then I should see "Listing Users"
    Then I should see listing users tabular attributes
