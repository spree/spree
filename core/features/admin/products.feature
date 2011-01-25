Feature: Admin visiting products

  Scenario: Visiting admin products page
    Given 2 products exist
    And I go to the admin home page
    When I follow "Products"
    Then I should see listing products tabular attributes with name ascending

  @javascript
  Scenario: admin products create
    Given I go to the admin home page
    When I follow "Products"
    When I follow "admin_new_product"
    Then async I should see "SKU" within "#new_product"
    When I fill in "product_name" with "Baseball Cap"
    When I fill in "product_sku" with "B100"
    When I fill in "product_price" with "100"
    When I fill in "product_available_on" with "2011/01/24"
    When I press "Create"
    Then I should see "Successfully created!"
    When I fill in "product_on_hand" with "100"
    When I press "Update"
    Then I should see "Successfully updated!"
    When I follow "Products"
