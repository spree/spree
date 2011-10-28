Feature: Admin managing adjustments

  Scenario: adjustments list
    Given the following orders exist:
      |completed at         | number |
      |2011-02-01 12:36:15  | R100   |
    Given an adjustment exists for order R100
    And I go to the admin home page
    When I follow the first admin_edit_spree_order link
    When I follow "Adjustments"
    Then I should see row 0 and column 0 to have value "Date/Time" with selector "table.index"
    Then I should see row 0 and column 1 to have value "Description" with selector "table.index"
    Then I should see row 0 and column 2 to have value "Amount" with selector "table.index"
    Then I should see row 1 and column 1 to have value "Shipping" with selector "table.index"
    Then I should see row 1 and column 2 to have value "$100.00" with selector "table.index"


  Scenario: admin creating new adjustment with validation error
    Given the following orders exist:
      |completed at         | number |
      |2011-02-01 12:36:15  | R100   |
    Given an adjustment exists for order R100
    And I go to the admin home page
    When I follow the first admin_edit_spree_order link
    When I follow "Adjustments"
    When I follow "New Adjustment" 
    When I fill in "adjustment_amount" with ""
    When I fill in "adjustment_label" with ""
    When I press "Continue"
    Then I should see "Label can't be blank"
    Then I should see "Amount is not a number"

  Scenario: admin creating new adjustment
    Given the following orders exist:
      |completed at         | number |
      |2011-02-01 12:36:15  | R100   |
    Given an adjustment exists for order R100
    And I go to the admin home page
    When I follow the first admin_edit_spree_order link
    When I follow "Adjustments"
    When I follow "New Adjustment" 
    When I fill in "adjustment_amount" with "10"
    When I fill in "adjustment_label" with "rebate"
    When I press "Continue"
    Then I should see "successfully created!"

  Scenario: admin editing an adjustment
    Given the following orders exist:
      |completed at         | number |
      |2011-02-01 12:36:15  | R100   |
    Given an adjustment exists for order R100
    And I go to the admin home page
    When I follow the first admin_edit_spree_order link
    When I follow "Adjustments"
    When I click first link from selector "table.index td.actions a.edit"
    When I fill in "adjustment_amount" with "99"
    When I fill in "adjustment_label" with "rebate 99"
    When I press "Continue"
    Then I should see "successfully updated!"
    Then I should see "rebate 99"
    Then I should see "$99.00"

  Scenario: admin editing anadjustment with validation error
    Given the following orders exist:
      |completed at         | number |
      |2011-02-01 12:36:15  | R100   |
    Given an adjustment exists for order R100
    And I go to the admin home page
    When I follow the first admin_edit_spree_order link
    When I follow "Adjustments"
    When I click first link from selector "table.index td.actions a.edit"
    When I fill in "adjustment_amount" with ""
    When I fill in "adjustment_label" with ""
    When I press "Continue"
    Then I should see "Label can't be blank"
    Then I should see "Amount is not a number"
