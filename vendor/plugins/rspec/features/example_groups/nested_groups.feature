Feature: Nested example groups

  As an RSpec user
  I want to nest examples groups
  So that I can better organize my examples

  Scenario: Run with ruby
    Given the file ../../examples/passing/stack_spec_with_nested_example_groups.rb
    When I run it with the ruby interpreter -fs
    Then the stdout should match /Stack \(empty\)/
    And the stdout should match /Stack \(full\)/

  Scenario: Run with spec
    Given the file ../../examples/passing/stack_spec_with_nested_example_groups.rb
    When I run it with the spec script -fs
    Then the stdout should match /Stack \(empty\)/
    And the stdout should match /Stack \(full\)/
