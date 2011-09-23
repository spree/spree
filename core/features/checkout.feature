Feature: Checkout
  In order to buy stuff
  As a user
  I should be warned about out of stock items

  @selenium @stop
  Scenario: Visitor make checkout as guest, without registration
    Given backordering is disabled
    When I add a product with name: "RoR Mug" to cart
    Then I should see "Shopping Cart" within "h1"
    Then product with name: "RoR Mug" goes out of stock
    When I follow "Checkout"
    Then I should see "An item in your cart has become unavailable."
    Then I should see "Out of Stock" within "span.out-of-stock"

    When I click first link from selector "a.delete"
    When I add a product with name: "RoR Shirt" to cart
    When I follow "Checkout"
    Then I should see "Checkout" within "h1"
