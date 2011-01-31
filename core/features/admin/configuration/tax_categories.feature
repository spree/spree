Feature: Admin > configurations > tax_categories

  Scenario: Visiting admin configurations tax_categories
    Given I go to the admin home page
    When I follow "Configuration"
    Given a tax category exists
    When I follow "Tax Categories"
    Then I should see "Listing Tax Categories"
    Then I should see listing tax categories tabular attributes

  Scenario: admin updating tax categories
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Tax Categories"
    When I follow "admin_new_tax_categories_link"
    Then I should see "New Tax Category"
    When I fill in "tax_category_name" with "sports goods"
    When I fill in "tax_category_description" with "sports goods desc"
    When I press "Create"
    Then I should see "Successfully created!"
