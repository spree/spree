Feature: Sign up
  In order to be able to make a purchase
  A visitor
  Should be able to sign up

  Scenario: User signs up with invalid data
     When I go to the sign up page
     And I fill in "Email" with "invalidemail"
     And I fill in "Password" with "password"
     And I fill in "Password confirmation" with ""
     And I press "Sign up"
     Then I should see error messages

  Scenario: User signs up with valid data
    When I go to the sign up page
    And I fill in "Email" with "email@person.com"
    And I fill in "Password" with "password"
    And I fill in "Password confirmation" with "password"
    And I press "Sign up"
    Then I should see "devise.registrations.signed_up" translation