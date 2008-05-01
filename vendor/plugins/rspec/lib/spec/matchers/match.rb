module Spec
  module Matchers
    
    class Match #:nodoc:
      def initialize(expected)
        @expected = expected
      end
      
      def matches?(actual)
        @actual = actual
        return true if actual =~ @expected
        return false
      end
      
      def failure_message
        return "expected #{@actual.inspect} to match #{@expected.inspect}", @expected, @actual
      end
      
      def negative_failure_message
        return "expected #{@actual.inspect} not to match #{@expected.inspect}", @expected, @actual
      end
      
      def description
        "match #{@expected.inspect}"
      end
    end
    
    # :call-seq:
    #   should match(regexp)
    #   should_not match(regexp)
    #
    # Given a Regexp, passes if actual =~ regexp
    #
    # == Examples
    #
    #   email.should match(/^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i)
    def match(regexp)
      Matchers::Match.new(regexp)
    end
  end
end
