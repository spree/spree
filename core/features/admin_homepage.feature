Feature: Admin home page
  In order to do administrative work
  I should be able to login as an admin

  Scenario: Visiting admin home page
    And I go to the admin home page
    Then I should see "Administration"
    Then page should have following links:
     | url                    | text          | within      |
     | /admin                 | Overview      | #admin-menu |
     | /admin/orders          | Orders        | #admin-menu |
     | /admin/products        | Products      | #admin-menu |
     | /admin/reports         | Reports       | #admin-menu |
     | /admin/configurations  | Configuration | #admin-menu |
     | /admin/users           | Users         | #admin-menu |
   Then I should see "Listing Orders"
   When I follow "Products"
   Then page should have following links:
    | url                    | text           | within      |
    | /admin/products        | Products       | #sub-menu   |
    | /admin/option_types    | Option Types   | #sub-menu   |
    | /admin/properties      | Properties     | #sub-menu   |
    | /admin/prototypes      | Prototypes     | #sub-menu   |
    | /admin/product_groups  | Product Groups | #sub-menu   |
   When I follow "Reports"
   Then I should see "Listing Reports"
   When I follow "Configuration"
   Then I should see "Configurations"
   Then page should have following links:
    | url                         | text                | within      |
    | /admin/general_settings     | General Settings    | #content    |
    | /admin/mail_methods         | Mail Methods        | #content    |
    | /admin/tax_categories       | Tax Categories      | #content    |
    | /admin/zones                | Zones               | #content    |
    | /admin/countries/214/states | States              | #content    |
    | /admin/payment_methods      | Payment Methods     | #content    |
    | /admin/taxonomies           | Taxonomies          | #content    |
    | /admin/shipping_methods     | Shipping Methods    | #content    |
    | /admin/shipping_categories  | Shipping Categories | #content    |
    | /admin/inventory_settings   | Inventory Settings  | #content    |
    | /admin/tax_rates            | Tax Rates           | #content    |
    | /admin/tax_settings         | Tax Settings        | #content    |
    | /admin/trackers             | Analytics Trackers  | #content    |
   When I follow "Users"
   Then I should see "Listing Users"
