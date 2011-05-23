Feature: Admin visiting prototypes

  Scenario: Visiting admin prototypes page
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
    And I go to the admin home page
    When I follow "Products"
    When I follow "Prototypes"
    Then verify data from "table.index" with following tabular values:
      | Name  | Action |
      | Shirt | ignore |
      | Mug   | ignore |
      | Bag   | ignore |


  @javascript
  Scenario: Visiting admin prototypes page to create new record
    When I go to the admin home page
    When I follow "Products"
    When I follow "Prototypes"
    When I follow "new_prototype_link"
    Then async I should see "New Prototype" within "#new_prototype"
    When I fill in "prototype_name" with "male shirts"
    When I press "Create"
    Then I should see "successfully created!"
    When I follow "Prototypes"
    When I click on first link with class "admin_edit_prototype"
    When I fill in "prototype_name" with "Shirt 99"
    When I press "Update"
    Then I should see "successfully updated!"
    Then I should see "Shirt 99"
