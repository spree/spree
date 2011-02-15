Feature: Admin visiting product groups

  Scenario: Visiting admin product groups page
    Given 2 product groups exist
    And I go to the admin home page
    When I follow "Products"
    When I follow "Product Groups"
    Then I should see listing product groups tabular attributes

  @javascript
  Scenario: creating new product group record
    Given I go to the admin home page
    When I follow "Products"
    When I follow "Product Groups"
    When I follow "new_product_group_link"
    Then async I should see "Product Group" within "#content"
    When I fill in "product_group_name" with "male shirts"
    When I press "Create"
    Then I should see "Successfully created!"
    When I follow "Product Groups"
    When I click on first link with class "admin_edit_product_group"
    When I fill in "product_group_name" with "most popular rails items 99"
    When I press "Update"
    When I follow "Product Groups"
    Then I should see "Successfully updated!"
    Then I should see "most popular rails items 99"
