@api
Feature: Products api description

  Background:
    Given I am a valid API user
    And I send and accept json

  Scenario: Retrieve a list of products
    Given 2 products exist
    When I send a GET request to "/api/products"
    Then the response status should be "200 OK"
    And the response should be an array with 2 products

  Scenario: Retrieve a list of products after searching
    Given the following products exist:
      | name                |
      | apache baseball cap |
      | zomg shirt          |
    When I send a GET request to "/api/products.json?search[name_like]=shirt"
    Then the response status should be "200 OK"
    And the response should be an array with 1 product
    Then the response should have product information for shirt

  Scenario: Retrieve a product
    Given 2 products exist
    When I send a GET request to "first product"
    Then the response status should be "200 OK"
    Then the response should have product information

