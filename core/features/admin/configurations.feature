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
    When I follow "Analytics Tracker"
    Then I should see "Analytics Trackers"


  Scenario: admin updating general settings
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "General Settings"
    When I follow "admin_general_settings_link"
    Then I should see "Edit General Settings"
    #Then TODO I presss "Update"

  Scenario: admin updating mail methods
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Mail Methods"
    When I follow "admin_new_mail_method_link"
    Then I should see "New Mail Method"
    When I press "Create"
    Then I should see "Successfully created!"

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

  Scenario: admin updating zones
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Zones"
    When I follow "admin_new_zone_link"
    Then I should see "New Zone"
    When I fill in "zone_name" with "asian"
    When I fill in "zone_description" with "asian zone"
    When I press "Create"
    Then I should see "Successfully created!"

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

  Scenario: admin updating taxonomies
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Taxonomies"
    When I follow "admin_new_taxonomy_link"
    Then I should see "New Taxonomy"
    When I fill in "taxonomy_name" with "sports"
    When I press "Create"
    Then I should see "Successfully created!"

  Scenario: admin updating shipping methods
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Shipping Methods"
    When I follow "admin_new_shipping_method_link"
    Then I should see "New Shipping Method"
    When I fill in "shipping_method_name" with "bullock cart"
    When I press "Create"
    Then I should see "Successfully created!"
    Then I should see "Editing Shipping Method"
    When I press "Update"
    Then I should see "Successfully updated!"

  Scenario: admin updating inventory settings
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Inventory Settings"
    Then I should see "Inventory Settings"
    Then I should see "Products with a zero inventory will be displayed"
    Then I should see "Backordering allowed"
    When I follow "admin_inventory_settings_link"
    When I uncheck "preferences_show_zero_stock_products"
    When I uncheck "preferences_allow_backorders"
    #When TODO fixme I press "Update"

  Scenario: admin updating analytics tracker
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Analytics Trackers"
    When I should see "Analytics Trackers"
    When I follow "admin_new_tracker_link"
    When I fill in "tracker_analytics_id" with "a100"
    When I press "Create"
    Then I should see "Successfully created!"
