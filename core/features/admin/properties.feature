Feature: Admin visiting properties

  Scenario: Visiting admin properties page
    Given 2 properties exist
    And I go to the admin home page
    When I follow "Products"
    When I follow "Properties"
    Then I should see listing properties tabular attributes
