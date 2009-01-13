Story: Getting correct output with flexmock

  As an RSpec user who prefers flexmock
  I want to be able to use flexmock without rspec mocks interfering

  Scenario: Mock with flexmock
    Given the file ../../resources/spec/spec_with_flexmock.rb
    When I run it with the ruby interpreter
    Then the exit code should be 0