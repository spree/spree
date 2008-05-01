module Spec
  module Matchers
    class BaseOperatorMatcher
      attr_reader :generated_description
      
      def initialize(target)
        @target = target
      end

      def ==(expected)
        @expected = expected
        __delegate_method_missing_to_target("==", expected)
      end

      def ===(expected)
        @expected = expected
        __delegate_method_missing_to_target("===", expected)
      end

      def =~(expected)
        @expected = expected
        __delegate_method_missing_to_target("=~", expected)
      end

      def >(expected)
        @expected = expected
        __delegate_method_missing_to_target(">", expected)
      end

      def >=(expected)
        @expected = expected
        __delegate_method_missing_to_target(">=", expected)
      end

      def <(expected)
        @expected = expected
        __delegate_method_missing_to_target("<", expected)
      end

      def <=(expected)
        @expected = expected
        __delegate_method_missing_to_target("<=", expected)
      end

      def fail_with_message(message)
        Spec::Expectations.fail_with(message, @expected, @target)
      end

    end

    class PositiveOperatorMatcher < BaseOperatorMatcher #:nodoc:

      def __delegate_method_missing_to_target(operator, expected)
        ::Spec::Matchers.generated_description = "should #{operator} #{expected.inspect}"
        return if @target.send(operator, expected)
        return fail_with_message("expected: #{expected.inspect},\n     got: #{@target.inspect} (using #{operator})") if ['==','===', '=~'].include?(operator)
        return fail_with_message("expected: #{operator} #{expected.inspect},\n     got: #{operator.gsub(/./, ' ')} #{@target.inspect}")
      end

    end

    class NegativeOperatorMatcher < BaseOperatorMatcher #:nodoc:

      def __delegate_method_missing_to_target(operator, expected)
        ::Spec::Matchers.generated_description = "should not #{operator} #{expected.inspect}"
        return unless @target.send(operator, expected)
        return fail_with_message("expected not: #{operator} #{expected.inspect},\n         got: #{operator.gsub(/./, ' ')} #{@target.inspect}")
      end

    end

  end
end
