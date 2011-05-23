Feature: Admin > configurations > tax_categories

  Scenario: admin visiting tax categories list
    Given a tax category exists
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Tax Categories"
    Then I should see "Listing Tax Categories"
    Then I should see tabular data for tax categories index

  Scenario: admin creating new tax category
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Tax Categories"
    When I follow "admin_new_tax_categories_link"
    Then I should see "New Tax Category"
    When I fill in "tax_category_name" with "sports goods"
    When I fill in "tax_category_description" with "sports goods desc"
    When I press "Create"
    Then I should see "successfully created!"

  Scenario: admin creating new tax category with validation error
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Tax Categories"
    When I follow "admin_new_tax_categories_link"
    Then I should see "New Tax Category"
    When I press "Create"
    Then I should see "Name can't be blank"

  Scenario: admin editing a tax category
    Given a tax category exists
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Tax Categories"
    When I click first link from selector "table#listing_tax_categories a.edit"
    When I fill in "tax_category_description" with "desc 99"
    When I press "Update"
    Then I should see "successfully updated!"
    Then I should see "desc 99"
