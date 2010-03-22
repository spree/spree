Feature: Search products
  In order to be able to search products
  A visitor
  
  Scenario: Visitor can search products by keywords
    Given the following products exist:
      | name          | price | available_on        | taxon |
      | Ruby Mug      | 15.99 | 2010-03-06 18:48:21 | Ruby  |
      | Ruby Bag      | 19.99 | 2010-03-06 18:48:21 | Bag   |
      | Apache Bag    | 17.99 | 2010-03-06 18:48:21 | Bag   |
      | Ruby T-Shirt  | 16.99 | 2020-03-06 18:48:21 | Ruby  |
    When I go to the homepage
    And fill in "keywords" with "ruby"
    And press "Search"
    Then I should see "Search results for 'ruby'"
    And I should see "Ruby Mug"
    And I should see "Ruby Bag"
    And I should not see "Apache Bag"
    And I should not see "Ruby T-Shirt"
    
    When I go to the homepage
    And fill in "keywords" with "ruby"
    And select "Ruby" from "taxon"
    And press "Search"
    Then I should see "Ruby" within "h1"
    And I should see "Search results for 'ruby'"
    And I should see "Ruby Mug"
    And I should not see "Ruby Bag"
    And I should not see "Apache Bag"
    And I should not see "Ruby T-Shirt"
    
    When I go to the homepage
    And fill in "keywords" with "hsgfhagsfg"
    And press "Search"
    Then I should see "No products found"
