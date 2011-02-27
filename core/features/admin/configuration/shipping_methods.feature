Feature: Admin > configurations > shipping_methods

  Scenario: Admin > configurations > shipping_methods
    Given I go to the admin home page
    When I follow "Configuration"
    Given 2 shipping methods exist
    When I follow "Shipping Methods"
    Then I should see listing shipping methods tabular attributes

  Scenario: admin updating shipping methods
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Shipping Methods"
    When I follow "admin_new_shipping_method_link"
    Then I should see "New Shipping Method"
    When I fill in "shipping_method_name" with "bullock cart"
    When I press "Create"
    Then I should see "successfully created!"
    Then I should see "Editing Shipping Method"
    When I press "Update"
    Then I should see "successfully updated!"
