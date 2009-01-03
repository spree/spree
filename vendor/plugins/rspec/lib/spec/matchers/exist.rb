module Spec
  module Matchers
    # :call-seq:
    #   should exist
    #   should_not exist
    #
    # Passes if actual.exist?
    def exist
      simple_matcher do |actual, matcher|
        matcher.failure_message = "expected #{actual.inspect} to exist, but it doesn't."
        matcher.negative_failure_message = "expected #{actual.inspect} to not exist, but it does."
        actual.exist?
      end
    end
  end
end
