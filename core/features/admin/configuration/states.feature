Feature: Admin > configurations > tax_categories

  Scenario: Visiting admin configurations states
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "States"
    Then I should see listing states tabular attributes
