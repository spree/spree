Feature: Admin > configurations > general_settings

  Scenario: Visiting admin configurations general_settings
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "General Settings"
    Then I should see "General Settings"
    Then I should see "Site Name"
    Then I should see "Site URL"
    Then I should see "Spree Demo Site"
    Then I should see "demo.spreecommerce.com"
    When I follow "admin_general_settings_link"
    Then I should see "Edit General Settings"
    #Then I press "Update" #=> FIXME
