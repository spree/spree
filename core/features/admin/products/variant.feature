Feature: Admin product variants

  Scenario: admin creates a new variant
    Given the following product with option types exist:
      | price | cost_price | weight | height | width | depth |
      | 1.99  | 1.00       | 2.5    | 3.0    | 1.0   | 1.5   |
    Given 2 option types exist
    When I go to the admin home page
    When I follow "Products"
    When I click first link from selector "table#listing_products a.edit"
    When I follow "Variants"
    When I follow "New Variant"
    Then the "variant_price" field should contain "1.99"
    And the "variant_cost_price" field should contain "1.00"
    And the "variant_weight" field should contain "2.5"
    And the "variant_height" field should contain "3.0"
    And the "variant_width" field should contain "1.0"
    And the "variant_depth" field should contain "1.5"
