Feature: Promotions which add adjustments to orders

  Background:
    Given I have an admin account of "admin@person.com/password"
    Given a payment method exists
    Given a shipping method exists

  @selenium_with_chrome @wip
  Scenario: Managing promotion action for creating line items
    Given a product with name: "RoR Mug", price: "40" exists
    When I log in as an admin user and go to the new promotion form
    And I fill in "Name" with "Order's total > $30"
    And I fill in "Usage Limit" with "100"
    And I press "Create"
    Then I should see "Editing Promotion"
    And I select "Create line items" from "Add action of type"
    And I press "Add" within "#action_fields"
    And I fill in "Name or SKU" with "RoR Mug"
    # For this to work we need to simulate pressing tab to select the autocomplete item
    And I fill in "Qty" with "2"
    # Allow the variant select to populate
    And I wait for 5 seconds
    And I press "Add" within ".add-line-item"

  @selenium
  Scenario: A coupon promotion with flat rate discount
    When I log in as an admin user and go to the new promotion form
    And I fill in "Name" with "Order's total > $30"
    And I fill in "Usage Limit" with "100"
    And I select "Coupon code added" from "Event"
    And I fill in "Code" with "ORDER_30"
    And I press "Create"
    Then I should see "Editing Promotion"

    When I select "Item total" from "Add rule of type"
    And I press "Add" within "#rule_fields"
    And I fill in "Order total meets these criteria" with "30"
    And I press "Update" within "#rule_fields"

    And I select "Create adjustment" from "Add action of type"
    And I press "Add" within "#action_fields"
    And I select "Flat Rate (per order)" from "Calculator"
    And I press "Update" within "#actions_container"
    And I fill in "Amount" with "5" within ".calculator-fields"
    And I press "Update" within "#actions_container"

    When I add a product with name: "RoR Mug", price: "40" to cart
    And I follow "Checkout"
    When I fill billing address with correct data
    And check "order_use_billing"
    And press "Save and Continue"
    When I choose "UPS Ground" as shipping method and "Check" as payment method and set coupon code to "ORDER_30"
    Then the existing order should have total at "47"

  @selenium
  Scenario: A single use coupon promotion with flat rate discount
    When I log in as an admin user and go to the new promotion form
    And I fill in "Name" with "Order's total > $30"
    And I fill in "Usage Limit" with "20"
    And I select "Coupon code added" from "Event"
    And I fill in "Code" with "SINGLE_USE"
    And I press "Create"
    Then I should see "Editing Promotion"

    When I select "Item total" from "Add rule of type"
    And I press "Add" within "#rule_fields"
    And I fill in "Order total meets these criteria" with "30"
    And I press "Update" within "#rule_fields"

    And I select "Create adjustment" from "Add action of type"
    And I press "Add" within "#action_fields"
    And I select "Flat Rate (per order)" from "Calculator"
    And I press "Update" within "#actions_container"
    And I fill in "Amount" with "5" within ".calculator-fields"
    And I press "Update" within "#actions_container"

    When I add a product with name: "RoR Mug", price: "40" to cart
    And I follow "Checkout"
    When I fill billing address with correct data
    And check "order_use_billing"
    And press "Save and Continue"
    When I choose "UPS Ground" as shipping method and "Check" as payment method and set coupon code to "SINGLE_USE"
    Then the existing order should have total at "47"

    When I follow "Logout"
    And I log in as "john@test.com/secret"

    And I add a product with name: "RoR Mug", price: "40" to cart
    And I follow "Checkout"
    When I fill billing address with correct data
    And check "order_use_billing"
    And press "Save and Continue"
    When I choose "UPS Ground" as shipping method and "Check" as payment method and set coupon code to "SINGLE_USE"
    Then the resulting order should have a total of "52"

    And I add a product with name: "RoR Mug", price: "40" to cart
    And I follow "Checkout"
    When I fill billing address with correct data
    And check "order_use_billing"
    And press "Save and Continue"
    When I choose "UPS Ground" as shipping method and "Check" as payment method and set coupon code to "SINGLE_USE"
    Then the resulting order should have a total of "52"

  @selenium
  Scenario: An automatic promotion with flat percent discount
    When I log in as an admin user and go to the new promotion form
    And I fill in "Name" with "Order's total > $30"
    And I fill in "Code" with ""
    And I select "Order contents changed" from "Event"
    And I press "Create"
    Then I should see "Editing Promotion"

    When I select "Item total" from "Add rule of type"
    And I press "Add" within "#rule_fields"
    And I fill in "Order total meets these criteria" with "30"
    And I press "Update" within "#rule_fields"

    And I select "Create adjustment" from "Add action of type"
    And I press "Add" within "#action_fields"
    And I select "Flat Percent" from "Calculator"
    And I press "Update" within "#actions_container"
    And I fill in "Flat Percent" with "10" within ".calculator-fields"
    And I press "Update" within "#actions_container"

    When I add a product with name: "RoR Mug", price: "40" to cart
    And I follow "Checkout"
    Then the existing order should have total at "36"
    When I add a product with name: "RoR Bag", price: "20" to cart
    And I follow "Checkout"
    Then the existing order should have total at "54"


  @selenium
  Scenario: An automatic promotion with free shipping
    When I log in as an admin user and go to the new promotion form
    And I fill in "Name" with "Free Shipping"
    And I fill in "Code" with ""
    And I press "Create"
    Then I should see "Editing Promotion"

    When I select "Item total" from "Add rule of type"
    And I press "Add" within "#rule_fields"
    And I fill in "Order total meets these criteria" with "30"
    And I press "Update" within "#rule_fields"

    And I select "Create adjustment" from "Add action of type"
    And I press "Add" within "#action_fields"
    And I select "Free Shipping" from "Calculator"
    And I press "Update" within "#actions_container"

    When I add a product with name: "RoR Bag", price: "20" to cart
    And I follow "Checkout"
    When I fill billing address with correct data
    And check "order_use_billing"
    And press "Save and Continue"
    When I choose "UPS Ground" as shipping method
    Then the existing order should have total at "31"
    And I should not see "Free Shipping"
    When I add a product with name: "RoR Book", price: "20" to cart
    And I follow "Checkout"
    Then I should see "Free Shipping"
    And the existing order should have total at "42"

  @selenium
  Scenario: An automatic promotion requiring a landing page to be visited
    When I log in as an admin user and go to the new promotion form
    And I fill in "Name" with "Deal"
    And I select "Order contents changed" from "Event"
    And I press "Create"
    Then I should see "Editing Promotion"

    When I select "Landing Page" from "Add rule of type"
    And I press "Add" within "#rule_fields"
    And I fill in "Path" with "cvv"
    And I press "Update" within "#rule_fields"

    When I select "Create adjustment" from "Add action of type"
    And I press "Add" within "#action_fields"
    And I select "Flat Rate (per order)" from "Calculator"
    And I press "Update" within "#actions_container"
    And I fill in "Amount" with "4" within ".calculator-fields"
    And I press "Update" within "#actions_container"

    When I add a product with name: "RoR Mug", price: "40" to cart
    Then the existing order should have total at "40"

    When I go to "/cvv"
    And I add a product with name: "RoR Mug", price: "40" to cart
    Then the existing order should have total at "76"

  @selenium
  Scenario: Ceasing to be eligible for a promotion with item total rule then becoming eligible again
    When I log in as an admin user and go to the new promotion form
    And I fill in "Name" with "Spend over $50 and save $5"
    And I select "Order contents changed" from "Event"
    And I press "Create"
    Then I should see "Editing Promotion"

    When I select "Item total" from "Add rule of type"
    And I press "Add" within "#rule_fields"
    And I fill in "Order total meets these criteria" with "50"
    And I press "Update" within "#rule_fields"

    And I select "Create adjustment" from "Add action of type"
    And I press "Add" within "#action_fields"
    And I select "Flat Rate (per order)" from "Calculator"
    And I press "Update" within "#actions_container"
    And I fill in "Amount" with "5" within ".calculator-fields"
    And I press "Update" within "#actions_container"

    When I add a product with name: "RoR Mug", price: "20" to cart
    Then the existing order should have total at "20"

    When I update the quantity on the first cart item to "2"
    Then the existing order should have total at "40"
    And the existing order should not have any promotion credits

    When I update the quantity on the first cart item to "3"
    Then the existing order should have total at "55"
    And the existing order should have 1 promotion credit

    When I update the quantity on the first cart item to "2"
    Then the existing order should have total at "40"
    And the existing order should have 1 promotion credit

    When I update the quantity on the first cart item to "3"
    Then the existing order should have total at "55"

  @selenium
  Scenario: Only counting the most valuable promotion adjustment in an order

    When I log in as an admin user and go to the new promotion form
    And I fill in "Name" with "$5 off"
    And I select "Order contents changed" from "Event"
    And I press "Create"
    Then I should see "Editing Promotion"
    When I select "Create adjustment" from "Add action of type"
    And I press "Add" within "#action_fields"
    And I select "Flat Rate (per order)" from "Calculator"
    And I press "Update" within "#actions_container"
    And I fill in "Amount" with "5" within ".calculator-fields"
    And I press "Update" within "#actions_container"

    When I go to admin promotions page
    When I follow "New Promotion"
    And I fill in "Name" with "%10 off"
    And I select "Order contents changed" from "Event"
    And I press "Create"
    Then I should see "Editing Promotion"
    When I select "Create adjustment" from "Add action of type"
    And I press "Add" within "#action_fields"
    And I select "Flat Percent" from "Calculator"
    And I press "Update" within "#actions_container"
    And I fill in "Flat Percent" with "10" within ".calculator-fields"
    And I press "Update" within "#actions_container"

    When I add a product with name: "RoR Mug", price: "20" to cart
    Then the existing order should have total at "15"
    And the existing order should have 2 promotion credits

    When I update the quantity on the first cart item to "2"
    Then the existing order should have total at "35"

    When I update the quantity on the first cart item to "3"
    Then the existing order should have total at "54"
