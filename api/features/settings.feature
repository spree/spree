@api
Feature: Settings for admin

  Background:
    Given I am a valid API user
    And I send and accept json

  Scenario: get all settings for admin
    When I send a GET request to "/api/settings"
    Then the response status should be "200 OK"
    And response "orders_per_page" should be "15"

  Scenario: set settings
    When I send a GET request to "/api/settings"
    Then the response status should be "200 OK"
    Then response "select_taxons_from_tree" should be "false"
    And response "orders_per_page" should be "15"
    When I set "" and PUT request to "/api/settings/update"
    Then the response status should be "200"
    When I send a GET request to "/api/settings"
    Then the response status should be "200 OK"
    Then response "select_taxons_from_tree" should be "true"
    And response "orders_per_page" should be "100"

  Scenario: get all settings for valid api user
    Given I am a valid API user but not admin
    When I send a GET request to "/api/settings"
    Then the response status should be "401"
