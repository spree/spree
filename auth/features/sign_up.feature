Feature: Sign up
  In order to be able to make a purchase
  A visitor
  Should be able to sign up

  Scenario: User signs up with invalid data
     When I go to the sign up page
     And I fill in "Email" with "invalid email"
     And I fill in "Password" with "password"
     And I fill in "Password Confirmation" with ""
     And I press "Create"
     Then I should see error messages

  Scenario: User signs up with valid data
    When I go to the sign up page
    And I fill in "Email" with "email@person.com"
    And I fill in "Password" with "password"
    And I fill in "Password Confirmation" with "password"
    And I press "Create"
    Then I should see "You have signed up successfully."
