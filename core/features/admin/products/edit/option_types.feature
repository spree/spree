Feature: Admin editing product's option types

  @javascript
  Scenario: editing option type
    When I go to the admin home page
    When I follow "Products"
    When I follow "Option Types"
    When I follow "new_option_type_link"
    When I fill in "option_type_name" with "shirt colors"
    When I fill in "option_type_presentation" with "colors"
    When I press "Create"
    Given the following products exist:
      | name                 | sku  | available_on        |
      | apache baseball cap  | A100 | 2011-01-01 01:01:01 |
      | apache baseball cap2 | B100 | 2011-01-01 01:01:01 |
      | zomg shirt           | Z100 | 2011-01-01 01:01:01 |
    Given count_on_hand is 10 for all products
    When I go to the admin home page
    When I follow "Products"
    When I click first link from selector "table#listing_products a.edit"
    When I follow "Option Types" within "#sidebar"
    Then I should see row 1 and column 0 to have value "None" with selector "table.index"
    When I click first link from selector "#new_opt_link a"
    Then async
    Then I wait for 2 seconds
    When I click first link from selector "#option-types table a"
    Then async
    Then I wait for 2 seconds
    Then I should see row 1 and column 0 to have value "shirt colors" with selector "table.index"
    Then I should see row 1 and column 1 to have value "colors" with selector "table.index"




