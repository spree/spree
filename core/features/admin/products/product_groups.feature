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
    Then I should see "successfully created!"
    When I follow "Product Groups"
    When I click on first link with class "admin_edit_product_group"
    When I fill in "product_group_name" with "most popular rails items 99"
    When I press "Update"
    Then async
    And  I should see "successfully updated!"
    When I follow "Product Groups"
    Then I should see "most popular rails items 99"



  @javascript
  Scenario: applying scope product name have following
    Given I go to the admin home page
    Given a product group exists
    When I follow "Products"
    When I follow "Product Groups"
    When I click on first link with class "admin_edit_product_group"
    When I select "Product name have following" from "product_scope_name"
    When I press "Add"
    Then async I should see "Product name have following" within "table#product_scopes"

  @javascript
  Scenario: applying scope product name or meta keywords have following
    Given I go to the admin home page
    Given a product group exists
    When I follow "Products"
    When I follow "Product Groups"
    When I click on first link with class "admin_edit_product_group"
    When I select "Product name or meta keywords have following" from "product_scope_name"
    When I press "Add"
    Then async I should see "Product name or meta keywords have following " within "table#product_scopes"

  @javascript
  Scenario: applying scope product name or description have following
    Given I go to the admin home page
    Given a product group exists
    When I follow "Products"
    When I follow "Product Groups"
    When I click on first link with class "admin_edit_product_group"
    When I select "Product name or description have following" from "product_scope_name"
    When I press "Add"
    Then async I should see "Product name or description have following " within "table#product_scopes"

  @javascript
  Scenario: applying scope product with ids
    Given I go to the admin home page
    Given a product group exists
    When I follow "Products"
    When I follow "Product Groups"
    When I click on first link with class "admin_edit_product_group"
    When I select "Products with IDs" from "product_scope_name"
    When I press "Add"
    Then async I should see "Products with IDs" within "table#product_scopes"

  @javascript
  Scenario: applying scope product with option and value
    Given I go to the admin home page
    Given a product group exists
    When I follow "Products"
    When I follow "Product Groups"
    When I click on first link with class "admin_edit_product_group"
    When I select "With option and value" from "product_scope_name"
    When I press "Add"
    Then async I should see "With option and value" within "table#product_scopes"

  @javascript
  Scenario: applying scope product with property
    Given I go to the admin home page
    Given a product group exists
    When I follow "Products"
    When I follow "Product Groups"
    When I click on first link with class "admin_edit_product_group"
    When I select "With property" from "product_scope_name"
    When I press "Add"
    Then async I should see "With property" within "table#product_scopes"

  @javascript
  Scenario: applying scope product with property value
    Given I go to the admin home page
    Given a product group exists
    When I follow "Products"
    When I follow "Product Groups"
    When I click on first link with class "admin_edit_product_group"
    When I select "With property value" from "product_scope_name"
    When I press "Add"
    Then async I should see "With property value" within "table#product_scopes"

  @javascript
  Scenario: applying scope product with value
    Given I go to the admin home page
    Given a product group exists
    When I follow "Products"
    When I follow "Product Groups"
    When I click on first link with class "admin_edit_product_group"
    When I select "With value" from "product_scope_name"
    When I press "Add"
    Then async I should see "With value" within "table#product_scopes"

  @javascript
  Scenario: applying scope product with option
    Given I go to the admin home page
    Given a product group exists
    When I follow "Products"
    When I follow "Product Groups"
    When I click on first link with class "admin_edit_product_group"
    When I select "With option" from "product_scope_name"
    When I press "Add"
    Then async I should see "With option" within "table#product_scopes"

  @javascript
  Scenario: applying scope product price between
    Given I go to the admin home page
    Given a product group exists
    When I follow "Products"
    When I follow "Product Groups"
    When I click on first link with class "admin_edit_product_group"
    When I select "Price between" from "product_scope_name"
    When I press "Add"
    Then async I should see "Price between" within "table#product_scopes"

  @javascript
  Scenario: applying scope product master price lesser or equal to
    Given I go to the admin home page
    Given a product group exists
    When I follow "Products"
    When I follow "Product Groups"
    When I click on first link with class "admin_edit_product_group"
    When I select "Master price lesser or equal to" from "product_scope_name"
    When I press "Add"
    Then async I should see "Master price lesser or equal to" within "table#product_scopes"

  @javascript
  Scenario: applying scope product master price greater or equal to
    Given I go to the admin home page
    Given a product group exists
    When I follow "Products"
    When I follow "Product Groups"
    When I click on first link with class "admin_edit_product_group"
    When I select "Master price greater or equal to" from "product_scope_name"
    When I press "Add"
    Then async I should see "Master price greater or equal to" within "table#product_scopes"

  @javascript
  Scenario: applying scope In taxons and all their descendants
    Given I go to the admin home page
    Given a product group exists
    When I follow "Products"
    When I follow "Product Groups"
    When I click on first link with class "admin_edit_product_group"
    When I select "In taxons and all their descendants" from "product_scope_name"
    When I press "Add"
    Then async I should see "In taxons and all their descendants" within "table#product_scopes"

  @javascript
  Scenario: applying scope In Taxon(without descendants)
    Given a product group exists
    Given I go to the admin home page
    When I follow "Products"
    When I follow "Product Groups"
    When I click on first link with class "admin_edit_product_group"
    When I select "In Taxon(without descendants)" from "product_scope_name"
    When I press "Add"
    Then async I should see "In Taxon(without descendants)" within "table#product_scopes"

  @javascript
  Scenario: Visiting admin product groups page to edit it
    Given a product group exists
    Given the following products exist:
      | name                  | updated_at          |
      | apache cap            | 2011-04-06 17:25:00 |
      | ruby on rails t-shirt | 2011-05-06 17:25:00 |
    And I go to the admin home page
    When I follow "Products"
    When I follow "Product Groups"
    When I click on first link with class "admin_edit_product_group"
    When I select "Ascend by product name" from "product_group_order_scope"
    When I press "Update"
    Then async
    Then I should see product groups products listing with ascend by product name
    And  I should see "successfully updated!"

    When I select "Descend by product name" from "product_group_order_scope"
    When I press "Update"
    Then async
    Then I should see product groups products listing with descend by product name
    And  I should see "successfully updated!"

    When I select "Ascend by actualization date" from "product_group_order_scope"
    When I press "Update"
    Then async
    Then I should see product groups products listing with ascend by product name
    And  I should see "successfully updated!"

    When I select "Descend by actualization date" from "product_group_order_scope"
    When I press "Update"
    Then async
    Then I should see product groups products listing with descend by product name
    And  I should see "successfully updated!"

    Given the price of apache cap is 10
    Given the price of rails t-shirt cap is 30 in product group context

    When I select "Ascend by product master price" from "product_group_order_scope"
    When I press "Update"
    Then async
    Then I should see product groups products listing with ascend by product name
    And  I should see "successfully updated!"

    When I select "Descend by product master price" from "product_group_order_scope"
    When I press "Update"
    Then async
    Then I should see product groups products listing with descend by product name
    And  I should see "successfully updated!"

    Given apache cap has 1 line item
    Given ruby on rails t-shirt has 2 line items

    When I select "Sort by popularity(most popular first)" from "product_group_order_scope"
    When I press "Update"
    Then async
    Then I should see product groups products listing with descend by product name
    And  I should see "successfully updated!"


