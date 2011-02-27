Feature: Admin visiting option types

  Scenario: admin visiting option types list
    Given 2 option types exist
    And I go to the admin home page
    When I follow "Products"
    When I follow "Option Types"
    Then I should see listing option types tabular attributes

  @javascript
  Scenario: admin creating a new option type
    When I go to the admin home page
    When I follow "Products"
    When I follow "Option Types"
    When I follow "new_option_type_link"
    Then I should see "New Option Type" within "#new_option_type"
    When I fill in "option_type_name" with "shirt colors"
    When I fill in "option_type_presentation" with "colors"
    When I press "Create"
    Then I should see "successfully created!"
    When I click first link from selector "#new_add_option_value a"
    Then I wait for 2 seconds
    When I custom fill in "table tr:last td.name input" with "color"
    When I custom fill in "table tr:last td.presentation input" with "black"
    When I press "Update"
    Then I should see "successfully updated!"

  Scenario: admin editing an option type
    Given 2 option types exist
    And I go to the admin home page
    When I follow "Products"
    When I follow "Option Types"
    When I click on first link with class "admin_edit_option_type"
    When I fill in "option_type_name" with "foo-size 99"
    When I press "Update"
    Then I should see "successfully updated!"
    Then I should see "foo-size 99"
