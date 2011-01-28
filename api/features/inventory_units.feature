@api
Feature: Inventory units api

  Background:
    Given I am a valid API user
    And I send and accept json

  Scenario: Retrieve a list of inventory units
    Given 2 inventory units exist
    When I send a GET request to "/api/inventory_units"
    Then the response status should be "200 OK"
    And the response should be an array with 2 inventory units

  Scenario: Retrieve an inventory unit
    Given 2 inventory units exist
    When I send a GET request to "first inventory unit"
    Then the response status should be "200 OK"
    Then the response should have inventory unit information

