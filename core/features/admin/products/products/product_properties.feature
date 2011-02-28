Feature: Admin editing products

    @javascript
  Scenario: admin managing product properties
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
    Then verify empty data from "table.index" with following tabular values:
      | Property  | Value | Action |

