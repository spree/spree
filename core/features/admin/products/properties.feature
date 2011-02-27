Feature: Admin visiting properties

  Scenario: admin visiting properties list page
    Given 2 properties exist
    And I go to the admin home page
    When I follow "Products"
    When I follow "Properties"
    Then I should see listing properties tabular attributes

  @javascript
  Scenario: admin creating a new property
    When I go to the admin home page
    When I follow "Products"
    When I follow "Properties"
    When I follow "new_property_link"
    Then async I should see "New Property" within "#new_property"
    When I fill in "property_name" with "color of band"
    When I fill in "property_presentation" with "color"
    When I press "Create"
    Then I should see "successfully created!"

  Scenario: admin editing a property
    Given a property exists
    When I go to the admin home page
    When I follow "Products"
    When I follow "Properties"
    When I click first link from selector "table#listing_properties a.edit"
    When I fill in "property_name" with "model 99"
    When I press "Update"
    Then I should see "successfully updated!"
    Then I should see "model 99"

  Scenario: admin editing a property with validation error
    Given a property exists
    When I go to the admin home page
    When I follow "Products"
    When I follow "Properties"
    When I click first link from selector "table#listing_properties a.edit"
    When I fill in "property_name" with ""
    When I press "Update"
    Then I should see "Name can't be blank"
