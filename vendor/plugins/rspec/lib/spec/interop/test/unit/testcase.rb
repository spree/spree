require 'test/unit/testcase'

module Test
  module Unit
    # This extension of the standard Test::Unit::TestCase makes RSpec
    # available from within, so that you can do things like:
    #
    # require 'test/unit'
    # require 'spec'
    #
    # class MyTest < Test::Unit::TestCase
    #   it "should work with Test::Unit assertions" do
    #     assert_equal 4, 2+1
    #   end
    #
    #   def test_should_work_with_rspec_expectations
    #     (3+1).should == 5
    #   end
    # end
    #
    # See also Spec::Example::ExampleGroup
    class TestCase
      extend Spec::Example::ExampleGroupMethods
      include Spec::Example::ExampleMethods

      def self.suite
        Test::Unit::TestSuiteAdapter.new(self)
      end

      def self.example_method?(method_name)
        should_method?(method_name) || test_method?(method_name)
      end

      def self.test_method?(method_name)
        method_name =~ /^test[_A-Z]./ && (
          instance_method(method_name).arity == 0 ||
          instance_method(method_name).arity == -1
        )
      end

      before(:each) {setup}
      after(:each) {teardown}

      def initialize(defined_description, options={}, &implementation)
        @_defined_description = defined_description
        
        # TODO - examples fail in rspec-rails if we remove "|| pending_implementation"
        #      - find a way to fail without it in rspec's code examples
        @_implementation = implementation || pending_implementation

        @_result = ::Test::Unit::TestResult.new
        # @method_name is important to set here because it complies with Test::Unit's interface.
        # Some Test::Unit extensions depend on @method_name being present.
        @method_name = @_defined_description

        # TODO - this is necessary to run single examples in rspec-rails, but I haven't
        # found a good way to write a failing example just within rspec core
        @_backtrace = caller
      end

      def run(ignore_this_argument=nil)
        super()
      end

    private

      def pending_implementation
        error = Spec::Example::NotYetImplementedError.new(caller)
        lambda { raise(error) }
      end
    end
  end
end
