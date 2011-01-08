Feature: Checkout
  In order to buy stuff
  As a user
  I should be able make checkout

  @selenium
  Scenario: Visitor make checkout as guest, without registration
    When I add a product with name: "RoR Mug" to cart
    Then I should see "Shopping Cart" within "h1"
    When I follow "Checkout"
    Then I should see "Registration"

    When I fill in "Email" with "spree@test.com" within "#guest_checkout"
    And press "Continue"
    Then I should see "Billing Address"
    And I should see "Shipping Address"

    When I fill billing address with correct data
    And check "order_use_billing"
    And press "Save and Continue"
    Then I should see "Shipping Method"
    When I choose "UPS Ground" as shipping method and "Check" as payment method
    Then I should see "Your order has been processed successfully"

  @selenium
  Scenario: Uncompleted guest order should be associated with user after log in
    Given I am signed up as "email@person.com/password"
    And I am logged out

    When I add a product with name: "RoR Mug" to cart
    Then 2 users should exist

    When I go to the sign in page
    And I sign in as "email@person.com/password"
    Then I should be logged in

    When I follow "Cart"
    Then I should see "RoR Mug"
    And I should see "Shopping Cart" within "h1"
    When I follow "Checkout"
    Then I should see "Billing Address"
    And I should see "Shipping Address"
    When I fill billing address with correct data
    And check "order_use_billing"
    And press "Save and Continue"
    Then I should see "Shipping Method"
    When I choose "UPS Ground" as shipping method and "Check" as payment method
    Then I should see "Your order has been processed successfully"
    And I should have 1 order

