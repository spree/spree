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
    Then show me the page
    Then I should see listing states tabular attributes

    When I follow "Configuration"
    When I follow "States"
    Then show me the page
    Then I should see listing states tabular attributes

    When I follow "Configuration"
    Given 2 payment methods exist
    When I follow "Payment Methods"
    Then show me the page
    Then I should see listing payment methods tabular attributes



