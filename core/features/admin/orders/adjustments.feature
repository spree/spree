Feature: Admin visiting orders

  Scenario: adjustments index
    Given the following orders exist:
      |completed at         | number |
      |2011-02-01 12:36:15  | R100   |
    Given an adjustment exists for order R100
    And I go to the admin home page
    When I follow the first admin_edit_order link
    When I follow "Adjustments"
    Then I should see tabular attributes for adjustments index

  Scenario: new adjustments with validation error
    Given the following orders exist:
      |completed at         | number |
      |2011-02-01 12:36:15  | R100   |
    Given an adjustment exists for order R100
    And I go to the admin home page
    When I follow the first admin_edit_order link
    When I follow "Adjustments"
    When I follow "New Adjustment" custom
    When I fill in "adjustment_amount" with ""
    When I fill in "adjustment_label" with ""
    When I press "Continue"
    Then I should see "Label can't be blank"
    Then I should see "Amount is not a number"

  Scenario: new adjustments
    Given the following orders exist:
      |completed at         | number |
      |2011-02-01 12:36:15  | R100   |
    Given an adjustment exists for order R100
    And I go to the admin home page
    When I follow the first admin_edit_order link
    When I follow "Adjustments"
    When I follow "New Adjustment" custom
    When I fill in "adjustment_amount" with "10"
    When I fill in "adjustment_label" with "rebate"
    When I press "Continue"
    Then I should see "Successfully created!"

  Scenario: edit adjustments
    Given the following orders exist:
      |completed at         | number |
      |2011-02-01 12:36:15  | R100   |
    Given an adjustment exists for order R100
    And I go to the admin home page
    When I follow the first admin_edit_order link
    When I follow "Adjustments"
    When I click first link from selector "table.index td.actions a.edit"
    When I fill in "adjustment_amount" with "99"
    When I fill in "adjustment_label" with "rebate 99"
    When I press "Continue"
    Then I should see "Successfully updated!"
    Then I should see "rebate 99"
    Then I should see "$99.00"

  Scenario: edit adjustments with validation error
    Given the following orders exist:
      |completed at         | number |
      |2011-02-01 12:36:15  | R100   |
    Given an adjustment exists for order R100
    And I go to the admin home page
    When I follow the first admin_edit_order link
    When I follow "Adjustments"
    When I click first link from selector "table.index td.actions a.edit"
    When I fill in "adjustment_amount" with ""
    When I fill in "adjustment_label" with ""
    When I press "Continue"
    Then I should see "Label can't be blank"
    Then I should see "Amount is not a number"
