Feature: Password reset
  In order to be able to login
  A visitor
  Should be able to reset their password

  Scenario: User indicates they have forgotten their password
    When I go to the login page
    And I follow "Forgot Password?"
    Then I should see "your password will be emailed to you"

  Scenario: User supplies an email for the password reset
    Given the following user exists:
      | email              | password | password_confirmation |
      | foobar@example.com | secret   | secret                |
    #Given a user exists with an email of "foobar@example.com"
    When I go to the forgot password page
    And I fill in "user_email" with "foobar@example.com"
    And I press "Reset my password"
    Then I should see "You will receive an email with instructions"
