@api
Feature: Line items api

  Background:
    Given I am a valid API user
    And I send and accept json

  Scenario: Retrieve a list of line items
    Given 2 custom line items exist
    When I send a GET request to "custom line items"
    Then the response status should be "200 OK"
    And the response should be an array with 2 line items

  Scenario: Retrieve a line item
    Given 2 line items exist
    When I send a GET request to "first line item"
    Then the response status should be "200 OK"
    Then the response should have line item information

