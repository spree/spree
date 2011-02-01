Feature: Visiting products

  @wip @stop
  Scenario: Visiting products page
    Given the following products exist:
      | name                |
      | apache baseball cap |
      | zomg shirt          |
    And I go to the home page
    When I fill in "keywords" with "shirt"
    When I press "Search"
    Then I should see "zomg shirt"

