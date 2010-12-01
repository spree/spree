Feature: Sign out
  In order to remove web session from the browser
  A User
  Should be able to sign out

  Scenario: User is signed in
    Given I am signed up as "email@person.com/password"
    When I go to the sign in page
    And I sign in as "email@person.com/password"
    And I follow "Logout"
    Then I should be logged out