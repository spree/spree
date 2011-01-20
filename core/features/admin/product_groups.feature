Feature: Admin visiting product groups

  Scenario: Visiting admin product groups page
    Given 2 product groups exist
    And I go to the admin home page
    When I follow "Products"
    When I follow "Product Groups"
    Then I should see listing product groups tabular attributes
