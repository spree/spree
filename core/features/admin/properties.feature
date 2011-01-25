Feature: Admin visiting properties

  Scenario: Visiting admin properties page
    Given 2 properties exist
    And I go to the admin home page
    When I follow "Products"
    When I follow "Properties"
    Then I should see listing properties tabular attributes

  @javascript
  Scenario: Visiting admin properties page to create new record
    When I go to the admin home page
    When I follow "Products"
    When I follow "Properties"
    When I follow "new_property_link"
    Then async I should see "New Property" within "#new_property"
    When I fill in "property_name" with "color of band"
    When I fill in "property_presentation" with "color"
    When I press "Create"
    Then I should see "Successfully created!"
