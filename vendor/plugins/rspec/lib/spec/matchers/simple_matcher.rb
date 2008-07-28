module Spec
  module Matchers
    class SimpleMatcher
      attr_writer :failure_message, :negative_failure_message, :description
      
      def initialize(description, &match_block)
        @description = description
        @match_block = match_block
      end

      def matches?(actual)
        @actual = actual
        case @match_block.arity
        when 2
          @match_block.call(@actual, self)
        else
          @match_block.call(@actual)
        end
      end
      
      def description
        @description || explanation
      end

      def failure_message
        @failure_message || (@description.nil? ? explanation : %[expected #{@description.inspect} but got #{@actual.inspect}])
      end

      def negative_failure_message
        @negative_failure_message || (@description.nil? ? explanation : %[expected not to get #{@description.inspect}, but got #{@actual.inspect}])
      end

      def explanation
        "No description provided. See RDoc for simple_matcher()"
      end
    end
  
    # simple_matcher makes it easy for you to create your own custom matchers
    # in just a few lines of code when you don't need all the power of a
    # completely custom matcher object.
    #
    # The <tt>description</tt> argument will appear as part of any failure
    # message, and is also the source for auto-generated descriptions.
    #
    # The <tt>match_block</tt> can have an arity of 1 or 2. The first block
    # argument will be the given value. The second, if the block accepts it
    # will be the matcher itself, giving you access to set custom failure
    # messages in favor of the defaults.
    #
    # The <tt>match_block</tt> should return a boolean: <tt>true</tt>
    # indicates a match, which will pass if you use <tt>should</tt> and fail
    # if you use <tt>should_not</tt>. false (or nil) indicates no match,
    # which will do the reverse: fail if you use <tt>should</tt> and pass if
    # you use <tt>should_not</tt>.
    #
    # An error in the <tt>match_block</tt> will bubble up, resulting in a
    # failure.
    #
    # == Example with default messages
    #
    #   def be_even
    #     simple_matcher("an even number") { |given| given % 2 == 0 }
    #   end
    #                    
    #   describe 2 do
    #     it "should be even" do
    #       2.should be_even
    #     end
    #   end
    #
    # Given an odd number, this example would produce an error message stating:
    # expected "an even number", got 3.
    #
    # Unfortunately, if you're a fan of auto-generated descriptions, this will
    # produce "should an even number." Not the most desirable result. You can
    # control that using custom messages:
    #
    # == Example with custom messages
    #
    #   def rhyme_with(expected)
    #     simple_matcher("rhyme with #{expected.inspect}") do |given, matcher|
    #       matcher.failure_message = "expected #{given.inspect} to rhyme with #{expected.inspect}"
    #       matcher.negative_failure_message = "expected #{given.inspect} not to rhyme with #{expected.inspect}"
    #       actual.rhymes_with? expected
    #     end
    #   end
    #
    #   # OR
    #
    #   def rhyme_with(expected)
    #     simple_matcher do |given, matcher|
    #       matcher.description = "rhyme with #{expected.inspect}"
    #       matcher.failure_message = "expected #{given.inspect} to rhyme with #{expected.inspect}"
    #       matcher.negative_failure_message = "expected #{given.inspect} not to rhyme with #{expected.inspect}"
    #       actual.rhymes_with? expected
    #     end
    #   end
    #
    #   describe "pecan" do
    #     it "should rhyme with 'be gone'" do
    #       nut = "pecan"
    #       nut.extend Rhymer
    #       nut.should rhyme_with("be gone")
    #     end
    #   end
    #
    # The resulting messages would be:
    #   description:              rhyme with "be gone"
    #   failure_message:          expected "pecan" to rhyme with "be gone"
    #   negative failure_message: expected "pecan" not to rhyme with "be gone"
    #
    # == Wrapped Expectations
    #
    # Because errors will bubble up, it is possible to wrap other expectations
    # in a SimpleMatcher.
    #
    #   def be_even
    #     simple_matcher("an even number") { |given| (given % 2).should == 0 }
    #   end
    #
    # BE VERY CAREFUL when you do this. Only use wrapped expectations for
    # matchers that will always be used in only the positive
    # (<tt>should</tt>) or negative (<tt>should_not</tt>), but not both.
    # The reason is that is you wrap a <tt>should</tt> and call the wrapper
    # with <tt>should_not</tt>, the correct result (the <tt>should</tt>
    # failing), will fail when you want it to pass.
    #
    def simple_matcher(description=nil, &match_block)
      SimpleMatcher.new(description, &match_block)
    end
  end
end