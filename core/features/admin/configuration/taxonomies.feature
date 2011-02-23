Feature: Admin > configurations > taxonomies

  Scenario: Admin > configurations > taxonomies
    Given I go to the admin home page
    When I follow "Configuration"
    Given 2 taxonomies exist
    When I follow "Taxonomies"
    Then I should see listing taxonomies tabular attributes

  Scenario: admin updating taxonomies
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Taxonomies"
    When I follow "admin_new_taxonomy_link"
    Then I should see "New Taxonomy"
    When I fill in "taxonomy_name" with "sports"
    When I press "Create"
    Then I should see "Successfully created!"
