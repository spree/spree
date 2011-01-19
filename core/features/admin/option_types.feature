Feature: Admin visiting option types

  Scenario: Visiting admin option types page
    Given 2 option types exist
    And I go to the admin home page
    When I follow "Products"
    When I follow "Option Types"
    Then I should see listing option types tabular attributes
