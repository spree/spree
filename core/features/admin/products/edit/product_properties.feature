Feature: Admin editing products

  Background:
    Given the following properties exist:
      | Name                | Presentation |
      | model               | Model        |
      | brand               | Brand        |
      | shirt_fabric        | Fabric       |
      | shirt_sleeve_length | Sleeve       |
      | mug_type            | Type         |
      | bag_type            | Type         |
      | manufacturer        | Manufacturer |
      | bag_size            | Size         |
      | mug_size            | Size         |
      | gender              | Gender       |
      | shirt_fit           | Fit          |
      | bag_material        | Material     |
      | shirt_type          | Type         |
    Given "Shirt" prototype has properties "brand, gender, manufacturer, model, shirt_fabric, shirt_fit, shirt_sleeve_length, shirt_type"
    Given "Mug" prototype has properties "mug_size, mug_type"
    Given "Bag" prototype has properties "bag_type, bag_material"
    Given custom taxons exist
    Given the following products exist:
      | name                 | sku  | available_on        |
      | apache baseball cap  | A100 | 2011-01-01 01:01:01 |
      | apache baseball cap2 | B100 | 2011-01-01 01:01:01 |
      | zomg shirt           | Z100 | 2011-01-01 01:01:01 |
    Given count_on_hand is 10 for all products
    When I go to the admin home page
    When I follow "Products"
    When I click first link from selector "table#listing_products a.edit"
    When I follow "Product Properties"

    @javascript
  Scenario: admin managing product properties
    Then verify empty table for selector "table.index"
    When I click first link from selector "p.add_product_properties a"
    Then I wait for 2 seconds
    When I custom fill in "table tr:last td.property_name input" with "shirt_type"
    When I custom fill in "table tr:last td.value input" with "black_shirt"
    When I press "Update"
    When I follow "Product Properties"
    Then I custom should see value "shirt_type" for selector "table tr:last td.property_name input"
    Then I custom should see value "black_shirt" for selector "table tr:last td.value input"
    When I click first link from selector "table tr:last td.actions a"
    Then I wait for 2 seconds
    When I press "Update"
    When I follow "Product Properties"
    Then verify empty table for selector "table.index"

    @javascript
  Scenario: admin managing product properties using prototypes
    Then verify empty table for selector "table.index"
    When I click first link from selector "#new_ptype_link a"
    Then I wait for 2 seconds
    When I click first link from selector "#prototypes table.index a"
    #Then FIXME
