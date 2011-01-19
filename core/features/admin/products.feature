Feature: Admin visiting products

  Scenario: Visiting admin products page
    Given 2 products exist
    And I go to the admin home page
    When I follow "Products"
    Then I should see listing products tabular attributes with name ascending
