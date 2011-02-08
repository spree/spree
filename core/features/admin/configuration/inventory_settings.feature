Feature: Admin > configurations > inventory_settings

  Scenario: Admin > configurations > inventory_settings
    Given I go to the admin home page
    When I follow "Configuration"
    When I follow "Inventory Settings"
    Then I should see "Inventory Settings"
    Then I should see "Products with a zero inventory will be displayed"
    Then I should see "Backordering allowed"
    When I follow "admin_inventory_settings_link"
    When I uncheck "preferences_show_zero_stock_products"
    When I uncheck "preferences_allow_backorders"
    #When I press "Update" #=> FIXME


