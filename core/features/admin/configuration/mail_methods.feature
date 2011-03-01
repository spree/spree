Feature: Admin > configurations > mail_methods

  Scenario: mail_methods index
    Given a mail method exists
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Mail Methods"
    Then I should see tabular data for mail methods index

  Scenario: create new mail_method
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Mail Methods"
    When I follow "admin_new_mail_method_link"
    Then I should see "New Mail Method"
    When I press "Create"
    Then I should see "Successfully created!"

  Scenario: edit mail_method
    Given a mail method exists
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Mail Methods"
    When I click first link from selector "table#mail_methods_listing a.edit"
    When I fill in "mail_method_preferred_mail_bcc" with "spree@example.com99"
    When I press "Update"
    Then I should see "Successfully updated!"
    When I click first link from selector "table#mail_methods_listing a.edit"
    Then the "mail_method_preferred_mail_bcc" field should contain "spree@example.com99"
