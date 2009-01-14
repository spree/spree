module Test
  module Unit
    class TestCase
      # Edge rails (r8664) introduces class-wide setup & teardown callbacks for Test::Unit::TestCase.
      # Make sure these still get run when running TestCases under rspec:
      prepend_before(:each) do
        run_callbacks :setup if respond_to?(:run_callbacks)
      end
      append_after(:each) do
        run_callbacks :teardown if respond_to?(:run_callbacks)
      end
    end
  end
end