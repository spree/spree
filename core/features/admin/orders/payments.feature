Feature: Admin visiting orders

  Scenario: payments list
    Given the following orders exist:
      |completed at         | number |
      |2011-02-01 12:36:15  | R100   |
    Given custom payment associated with order R100
    And I go to the admin home page
    When I follow the first admin_edit_order link
    #When I follow "Payments" FIXME
    #Then I should see "checkout" within "table.index"
