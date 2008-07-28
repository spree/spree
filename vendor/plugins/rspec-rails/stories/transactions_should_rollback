Story: transactions should rollback in plain text
  As an RSpec/Rails Story author
  I want transactions to roll back between scenarios in plain text
  So that I can have confidence in the state of the database

  Scenario: add one Person
    When I add a Person

  Scenario: add another person
    GivenScenario: add one Person
    Then there should be one person

  Scenario: add yet another person
    GivenScenario: add one Person
    Then there should be one person
