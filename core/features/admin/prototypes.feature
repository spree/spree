Feature: Admin visiting prototypes

  Scenario: Visiting admin prototypes page
    Given 2 prototypes exist
    And I go to the admin home page
    When I follow "Products"
    When I follow "Prototypes"
    Then I should see listing prototypes tabular attributes
