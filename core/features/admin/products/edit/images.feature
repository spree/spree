Feature: Admin editing products

  Scenario: admin uploading and then editing an image for a product
    Given the following products exist:
      | name                 | sku  | available_on        |
      | apache baseball cap  | A100 | 2011-01-01 01:01:01 |
      | apache baseball cap2 | B100 | 2011-01-01 01:01:01 |
      | zomg shirt           | Z100 | 2011-01-01 01:01:01 |
    Given count_on_hand is 10 for all products
    When I go to the admin home page
    When I follow "Products"
    When I click first link from selector "table#listing_products a.edit"
    When I follow "Images"
    When I follow "new_image_link"
    When I attach file "ror_ringer.jpeg" to "image_attachment"
    When I press "Update"
    Then I should see "successfully created!"
    When I click first link from selector "table.index a.edit"
    When I fill in "image_alt" with "ruby on rails t-shirt"
    When I press "Update"
    Then I should see "successfully updated!"
    Then I should see "ruby on rails t-shirt"
