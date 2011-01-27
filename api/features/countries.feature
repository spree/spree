@api
Feature: Countries api

  Background:
    Given I am a valid API user
    And I send and accept json

  Scenario: Retrieve a list of countries
    When I send a GET request to "/api/countries"
    Then the response status should be "200 OK"
    And the response should be an array with 100 countries

