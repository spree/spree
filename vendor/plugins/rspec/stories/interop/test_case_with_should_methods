Story: Test::Unit::TestCase extended by rspec with should methods

  As an RSpec adopter with existing Test::Unit tests
  I want to use should_* methods in a Test::Unit::TestCase
  So that I use RSpec with classes and methods that look more like RSpec examples

  Scenario: Run with ruby
    Given the file test/test_case_with_should_methods.rb
    When I run it with the ruby interpreter
    Then the exit code should be 256
    And the stdout should match "5 examples, 3 failures"

  Scenario: Run with spec
    Given the file test/test_case_with_should_methods.rb
    When I run it with the spec script
    Then the exit code should be 256
    And the stdout should match "5 examples, 3 failures"
