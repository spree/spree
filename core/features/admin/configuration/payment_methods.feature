Feature: Admin > configurations > payment_methods

  Scenario: Admin > configurations > payment_methods
    Given I go to the admin home page
    When I follow "Configuration"
    Given 2 payment methods exist
    When I follow "Payment Methods"
    Then I should see listing payment methods tabular attributes

  Scenario: admin updating payment methods
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Payment Methods"
    When I follow "admin_new_payment_methods_link"
    Then I should see "New Payment Method"
    When I fill in "payment_method_name" with "check90"
    When I fill in "payment_method_description" with "check90 desc"
    When I press "Create"
    Then I should see "Successfully created!"
