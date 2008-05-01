module Spec
  module Matchers
    class SmartMatch
      def initialize(expected)
        @expected = expected
      end

      def matches?(actual)
        @actual = actual
        # Satisfy expectation here. Return false or raise an error if it's not met.

        if @expected =~ /^\/.*\/?$/ || @expected =~ /^".*"$/
          regex_or_string = eval(@expected)
          if Regexp === regex_or_string
            (@actual =~ regex_or_string) ? true : false
          else
            @actual.index(regex_or_string) != nil
          end
        else
          false
        end
      end

      def failure_message
        "expected #{@actual.inspect} to smart_match #{@expected.inspect}, but it didn't"
      end

      def negative_failure_message
        "expected #{@actual.inspect} not to smart_match #{@expected.inspect}, but it did"
      end
    end

    def smart_match(expected)
      SmartMatch.new(expected)
    end
  end
end