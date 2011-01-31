Feature: Admin > configurations > mail_methods

  Scenario: Visiting admin configurations mail_methods
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Mail Methods"
    When I follow "admin_new_mail_method_link"
    Then I should see "New Mail Method"
    When I press "Create"
    Then I should see "Successfully created!"
