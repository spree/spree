Feature: View Order
  In order to provide secure access to the user's order
  A User
  Should be able to view their cart at any time

  Scenario: User returns to their empty cart
    When I go to the cart page
    Then I should see "Your cart is empty"

  Scenario: User returns to their empty cart
    Given I am on the cart page
    When I go to the home page
    And I return to the cart page
    Then I should see "Your cart is empty"