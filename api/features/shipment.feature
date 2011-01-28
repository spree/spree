@api
Feature: Shipments api description

  Background:
    Given I am a valid API user
    And I send and accept json

  Scenario: Retrieve a list of shipments
    Given 2 shipments exist
    When I send a GET request to "/api/shipments"
    Then the response status should be "200 OK"
    And the response should be an array with 2 shipments

  Scenario: Retrieve a shipment
    Given 2 shipments exist
    When I send a GET request to "first shipment"
    Then the response status should be "200 OK"
    Then the response should have shipment information
