Feature: Admin visiting configurations

  Scenario: Visiting admin configurations page
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "General Settings"
    Then I should see "General Settings"
    Then I should see "Site Name"
    Then I should see "Site URL"
    Then I should see "Spree Demo Site"
    Then I should see "demo.spreecommerce.com"

    When I follow "Configuration"
    When I follow "Mail Methods"

    When I follow "Configuration"
    Given a tax category exists
    When I follow "Tax Categories"
    Then I should see "Listing Tax Categories"
    Then I should see listing tax categories tabular attributes

    When I follow "Configuration"
    Given 2 zones exist
    When I follow "Zones"
    Then I should see listing zones tabular attributes

    When I follow "Configuration"
    When I follow "States"
    Then I should see listing states tabular attributes

    When I follow "Configuration"
    When I follow "States"
    Then I should see listing states tabular attributes

    When I follow "Configuration"
    Given 2 payment methods exist
    When I follow "Payment Methods"
    Then I should see listing payment methods tabular attributes

    When I follow "Configuration"
    Given 2 taxonomies exist
    When I follow "Taxonomies"
    Then I should see listing taxonomies tabular attributes

    When I follow "Configuration"
    Given 2 shipping methods exist
    When I follow "Shipping Methods"
    Then I should see listing shipping methods tabular attributes

    When I follow "Configuration"
    When I follow "Inventory Settings"
    Then I should see "Inventory Settings"
    Then I should see "Products with a zero inventory will be displayed"

    When I follow "Configuration"
    When I follow "Analytics Tracker"
    Then I should see "Analytics Trackers"


  Scenario: admin updating general settings
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "General Settings"
    When I follow "admin_general_settings_link"
    Then I should see "Edit General Settings"
    #Then TODO I presss "Update"
