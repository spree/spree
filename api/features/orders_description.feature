@api
Feature: Orders api description
  In order to get details on order that have been placed
  As a developer
  I want to see order details placed from my storefront

  Background:
    Given I am a valid API user
    And I send and accept json

  Scenario: Retrieve a list of my orders
    Given I have 5 orders
    When I send a GET request to "/api/orders"
    Then the response status should be "200 OK"
    And the response should be an array with 5 orders
