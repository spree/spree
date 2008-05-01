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

      before(:each) {setup}
      after(:each) {teardown}

      class << self
        def suite
          Test::Unit::TestSuiteAdapter.new(self)
        end

        def example_method?(method_name)
          should_method?(method_name) || test_method?(method_name)
        end

        def test_method?(method_name)
          method_name =~ /^test[_A-Z]./ && (
            instance_method(method_name).arity == 0 ||
            instance_method(method_name).arity == -1
          )
        end
      end

      def initialize(defined_description, &implementation)
        @_defined_description = defined_description
        @_implementation = implementation

        @_result = ::Test::Unit::TestResult.new
        # @method_name is important to set here because it "complies" with Test::Unit's interface.
        # Some Test::Unit extensions depend on @method_name being present.
        @method_name = @_defined_description
      end

      def run(ignore_this_argument=nil)
        super()
      end
    end
  end
end
