Story: Test is defined, but not Test::Unit

  As an RSpec user who has my own library named Test (but not Test::Unit)
  I want to run examples without getting Test::Unit NameErrors

  Scenario: Run with ruby
    Given the file ../../resources/test/spec_including_test_but_not_unit.rb
    When I run it with the ruby interpreter
    Then the stderr should not match "Test::Unit"

  Scenario: Run with spec
    Given the file ../../resources/test/spec_including_test_but_not_unit.rb
    When I run it with the spec script
    Then the stderr should not match "Test::Unit"
