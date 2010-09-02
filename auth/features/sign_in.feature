Feature: Sign in
  In order to make a purchase
  A User
  Should be able to sign in

  Scenario: User signs in successfully
    Given I am signed up as "email@person.com/password"
    When I go to the sign in page
    And I sign in as "email@person.com/password"
    Then I should see "devise.sessions.signed_in" translation
    And I should be signed in
  
  Scenario: User is not signed up
    Given no user exists with an email of "email@person.com"
    When I go to the sign in page
    And I sign in as "email@person.com/password"
    Then I should see "devise.failure.invalid" translation
    And I should be signed out
  
  Scenario: User enters wrong password
    Given I am signed up as "email@person.com/password"
    When I go to the sign in page
    And I sign in as "email@person.com/wrongpassword"
    Then I should see "devise.failure.invalid" translation
    And I should be signed out