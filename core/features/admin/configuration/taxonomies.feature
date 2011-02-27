Feature: Admin > configurations > taxonomies

  Scenario: admin visiting taxonomies list
    Given I go to the admin home page
    When I follow "Configuration"
    Given 2 taxonomies exist
    When I follow "Taxonomies"
    Then I should see tabular data for taxonomies list

  Scenario: admin creating new taxonomy
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Taxonomies"
    When I follow "admin_new_taxonomy_link"
    Then I should see "New Taxonomy"
    When I fill in "taxonomy_name" with "sports"
    When I press "Create"
    Then I should see "successfully created!"

  Scenario: admin creating new taxonomy with validation error
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Taxonomies"
    When I follow "admin_new_taxonomy_link"
    Then I should see "New Taxonomy"
    When I fill in "taxonomy_name" with ""
    When I press "Create"
    #FIXME the message below should actually be Name can't be blank
    Then I should see "can't be blank"

  Scenario: admin editing taxonomy
    Given 2 taxonomies exist
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Taxonomies"
    When I click first link from selector "table#listing_taxonomies a.edit"
    Then I should see "Edit taxonomy"
    When I fill in "taxonomy_name" with "sports 99"
    When I press "Update"
    Then I should see "successfully updated!"
    Then I should see "sports 99"

