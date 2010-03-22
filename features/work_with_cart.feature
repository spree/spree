Feature: Work with cart

  Scenario: Visitor can work with cart
    When I add a product with name: "RoR Mug", price: "15" to cart
    Then I should see "Shopping Cart" within "h1"
    And I should see "RoR Mug" within "#line_items h4 a"
    And I should see "$15" within "#line_items td"
    And I should see "$15" within "#subtotal"
    
    When I add a product with name: "RoR Mug", price: "15" to cart
    Then I should see "Shopping Cart" within "h1"
    And I should see "RoR Mug" within "#line_items h4 a"
    And I should see "$15" within "#line_items td"
    And I should see "$30" within "#line_items td"
    And I should see "$30" within "#subtotal"
    
    When I add a product with name: "RoR Bag", price: "17" to cart
    Then I should see "Shopping Cart" within "h1"
    And I should see "RoR Bag" within "#line_items h4 a"
    And I should see "$15" within "#line_items td"
    And I should see "$17" within "#line_items td"
    And I should see "$47" within "#subtotal"
    
    When I fill in "order_line_items_attributes_0_quantity" with "3"
    Then the "order_line_items_attributes_0_quantity" field should contain "3"
    # When I press "order_line_items_attributes_0_quantity"
    # Then I should see "Shopping Cart" within "h1"
    # And I should see "$45" within "#line_items td"
    # And I should see "$62" within "#subtotal"
    
    # When I fill in "order_line_items_attributes_0_quantity" with "0"
    # And follow "Update"
    # Then I should see "Shopping Cart" within "h1"
    # And I should see "$17" within "#subtotal"
    
    
  Scenario: Following by cart link should not create order
    When I go to the homepage
    And follow "Cart"
    When 0 orders should exist
    
