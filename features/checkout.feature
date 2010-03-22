Feature: Checkout
  In order to be able make checkout
  Should be able make checkout

  
  Scenario: Visitor make checkout as guest, without registration
    When I add a product with name: "RoR Mug" to cart
    Then I should see "Shopping Cart" within "h1"
    When I follow "Checkout"
    Then I should see "Registration"
    
    When I fill in "Email" with "spree@test.com" within "#guest_checkout"
    And press "Continue"
    Then I should see "Billing Address" within "legend"
    And I should see "Shipping Address" within "legend"
    
    When I fill billing address with correct data
    And check "checkout_use_billing"
    And press "Save and Continue"
    Then I should see "Shipping Method" within "legend"
    When I fill in "coupon-code" with "SPREE"
    And press "post-summary"
    Then I should see "Coupon (SPREE)" within "#summary-order-credits"
    And I should see "Shipping Method" within "legend"
    
    When I choose "UPS Ground" as shipping method and "Check" as payment method
    Then I should see "Your order has been processed successfully"
    And 1 coupon_credits should exist


  Scenario: User make checkout
    Given I am signed up as "email@person.com/password"
    When I add a product with name: "RoR Mug" to cart
    Then I should see "Shopping Cart" within "h1"
    When I follow "Checkout"
    Then I should see "Registration"
    
    When I follow "Log In as Existing Customer"
    Then I should see "Log In as Existing Customer" within "h2"
    When I sign in as "email@person.com/password"
    Then I should see "Billing Address" within "legend"
    And I should see "Shipping Address" within "legend"
    
    When I press "Save and Continue"
    Then I should see "Shipping Method" within "legend"
    When I fill in "coupon-code" with "SPREE"
    And press "post-summary"
    Then I should see "Coupon (SPREE)" within "#summary-order-credits"
    And I should see "Shipping Method" within "legend"
    
    When I choose "UPS Ground" as shipping method and "Check" as payment method
    Then I should see "Your order has been processed successfully"
    And 1 coupon_credits should exist

    
  Scenario: Uncompleted order associated with user
    Given I am signed up as "email@person.com/password"
    When I sign in as "email@person.com/password"
    Then I should be logged in

    When I add a product with price: "14.99" to cart
    Then 1 orders should exist with item_total: "14.99"
    And 0 orders should exist with user_id: nil
    
    When I follow "Logout"
    Then I should be logged out
    And cart should be empty
    When I add a product with price: "14.99" to cart
    Then 2 orders should exist with item_total: "14.99"
    And 1 orders should exist with user_id: nil
    
    When I sign in as "email@person.com/password"
    Then 1 orders should exist with item_total: "29.98"
    And 0 orders should exist with user_id: nil


  Scenario: Uncompleted guest order should be associated with user after log in
    Given I am signed up as "email@person.com/password"
    
    When I add a product with name: "RoR Mug" to cart
    Then 1 orders should exist with user_id: nil  
    
    When I go to the sign in page
    And sign in as "email@person.com/password"
    Then I should be logged in
    
    When I follow "Cart"
    Then I should see "Shopping Cart" within "h1"   
    When I follow "Checkout"
    Then I should see "Billing Address"
    And I should see "Shipping Address" within "legend"
    When I press "Save and Continue"
    Then I should see "Shipping Method" within "legend"
    When I choose "UPS Ground" as shipping method and "Check" as payment method
    Then I should see "Your order has been processed successfully"
    And 0 orders should exist with user_id: nil
  
  
