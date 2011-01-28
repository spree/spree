@api
Feature: Products api description

  Background:
    Given I am a valid API user
    And I send and accept json

  Scenario: Retrieve a list of products
    Given 2 products exist
    When the following products exist:
      | deleted_at | available_on        |
      |            | 2010-01-31 17:13:55 |
      |            | 2010-01-31 17:13:55 |
    When I send a GET request to "/api/products"
    Then the response status should be "200 OK"
    And the response should be an array with 2 products

  Scenario: Retrieve a product
    When the following products exist:
      | deleted_at | available_on        |
      |            | 2010-01-31 17:13:55 |
      |            | 2010-01-31 17:13:55 |
    When I send a GET request to "first product"
    Then the response status should be "200 OK"
    Then the response should have product information

