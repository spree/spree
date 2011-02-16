Feature: Admin > configurations > general_settings

  Scenario: visit general settings (admin)
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "General Settings"
    Then I should see "General Settings"
    Then I should see "Site Name"
    Then I should see "Site URL"
    Then I should see "Spree Demo Site"
    Then I should see "demo.spreecommerce.com"

  Scenario: edit general settings (admin)
    Given preference settings exist
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "General Settings"
    When I follow "admin_general_settings_link"
    Then I should see "Edit General Settings"
    Then I fill in "preferences_site_name" with "Spree Demo Site99"
    Then I press "Update"
    #Then I should see "Spree Demo Site99" #=> FIXME expected #has_content?("Spree Demo Site99") to return true, got false
