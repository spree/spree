Feature: Order's total

  @selenium
  Scenario: Add promotion with order's total
    Given I have an admin account of "admin@person.com/password"
    Given a payment method exists
    Given a shipping method exists
    When I go to the sign in page
    And I sign in as "admin@person.com/password"
    And I go to admin promotions page
    When I follow "New Promotion"
    And I fill in "Name" with "Order's total > $30"
    And I fill in "Code" with "ORDER_30"
    And I select "Flat Rate (per order)" from "Calculator"
    And I press "Create"
    Then I should see "Editing Promotion"
    When I fill in "Amount" with "5" within ".calculator-settings"
    And I press "Update"
    And I select "Item total" from "Add rule of type"
    And I press "Add" within "#rule_fields"
    And I fill in "Item total must be" with "30"
    And I press "Update" within "#rule_fields"
    When I add a product with name: "RoR Mug", price: "40" to cart
    And I follow "Checkout"
    When I fill billing address with correct data
    And check "order_use_billing"
    And press "Save and Continue"
    When I choose "UPS Ground" as shipping method and "Check" as payment method and set coupon code to "ORDER_30"
    Then the existing order should have total at "47"

