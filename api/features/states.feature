@api
Feature: States api

  Background:
    Given I am a valid API user
    And I send and accept json

  Scenario: Retrieve a list of states
    When I send a GET request to "custom states list"
    Then the response status should be "200 OK"
    And the response should be an array with 51 states

  Scenario: Retrieve a state
    When I send a GET request to "first state"
    Then the response status should be "200 OK"
    Then the response should have state information
