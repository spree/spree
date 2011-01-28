@api
Feature: Orders api description

  Background:
    Given I am a valid API user
    And I send and accept json

  Scenario: Retrieve a list of my orders
    Given I have 5 orders
    When I send a GET request to "/api/orders"
    Then the response status should be "200 OK"
    And the response should be an array with 5 orders

  Scenario: Retrieve an order
    Given I have 2 orders
    When I send a GET request to "first order"
    Then the response status should be "200 OK"
    Then the response should have order information
