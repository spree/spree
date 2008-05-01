module Spec
  module Matchers
    class Exist
      def matches? actual
        @actual = actual
        @actual.exist?
      end
      def failure_message
        "expected #{@actual.inspect} to exist, but it doesn't."
      end
      def negative_failure_message
        "expected #{@actual.inspect} to not exist, but it does."
      end
    end
    def exist; Exist.new; end
  end
end
