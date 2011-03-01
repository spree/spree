Feature: Checkout
  In order to buy stuff
  As a user
  I should be able make checkout

  @selenium @wip @stop
  Scenario: Visitor make checkout as guest, without registration
    Given a shipping method exists
    Given a payment method exists
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

  @selenium @wip @stop
  Scenario: Uncompleted guest order should be associated with user after log in
    Given a shipping method exists
    Given a payment method exists
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

  @selenium @stop
  Scenario: User registers during checkout
    Given a shipping method exists
    Given a payment method exists
    When I add a product with name: "RoR Mug" to cart
    Then I should see "Shopping Cart" within "h1"
    When I follow "Checkout"
    Then I should see "Registration"
    When I follow "Create a new account"

    When I fill in "Email" with "email@person.com"
    When I fill in "Password" with "spree123"
    When I fill in "Password Confirmation" with "spree123"
    And press "Create"
    Then I should see "You have signed up successfully."

    When I fill billing address with correct data
    And check "order_use_billing"
    And press "Save and Continue"

    Then I should see "Shipping Method"
    When I choose "UPS Ground" as shipping method and "Check" as payment method

    Then I should see "Your order has been processed successfully"
    And I should have 1 order

  @selenium
  Scenario: The current payment method does not support profiles
    Given a shipping method exists
    Given a authorize net payment method exists
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
    When I choose "UPS Ground" as shipping method

    When I enter valid credit card details
    Then I should not see "Confirm"

  @selenium @wip @stop
  Scenario: When no shipping methods have been configured
    Given a authorize net payment method exists
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
    Then I should see "No shipping methods available"

  @selenium
  Scenario: When multiple payment methods have been configured
    Given a shipping method exists
    Given a payment method exists
    Given a authorize net payment method exists
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
    When I choose "UPS Ground" as shipping method

    When I choose "Credit Card"
    And I enter valid credit card details
    Then I should not see "undefined method `authorize'"
