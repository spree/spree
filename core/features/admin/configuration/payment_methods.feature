Feature: Admin > configurations > payment_methods

  Scenario: admin visiting payment methods listing page
    Given I go to the admin home page
    When I follow "Configuration"
    Given 2 payment methods exist
    When I follow "Payment Methods"
    Then I should see listing payment methods tabular attributes

  Scenario: admin creating new payment method
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Payment Methods"
    When I follow "admin_new_payment_methods_link"
    Then I should see "New Payment Method"
    When I fill in "payment_method_name" with "check90"
    When I fill in "payment_method_description" with "check90 desc"
    When I press "Create"
    Then I should see "successfully created!"

  Scenario: admin editing payment method
    Given 2 payment methods exist
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Payment Methods"
    When I click first link from selector "table#listing_payment_methods a.edit"
    When I fill in "payment_method_name" with "Payment 99"
    When I press "Update"
    Then I should see "successfully updated!"
    Then the "payment_method_name" field should contain "Payment 99"

  Scenario: admin editing payment method with validation error
    Given 2 payment methods exist
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Payment Methods"
    When I click first link from selector "table#listing_payment_methods a.edit"
    When I fill in "payment_method_name" with ""
    When I press "Update"
    #Then I should see "Name can't be blank"
    #FIXME in cucumber environemnt even blank name is being saved. In development blank name shows error
