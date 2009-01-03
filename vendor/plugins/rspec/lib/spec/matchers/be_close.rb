module Spec
  module Matchers

    # :call-seq:
    #   should be_close(expected, delta)
    #   should_not be_close(expected, delta)
    #
    # Passes if actual == expected +/- delta
    #
    # == Example
    #
    #   result.should be_close(3.0, 0.5)
    def be_close(expected, delta)
      simple_matcher do |actual, matcher|
        matcher.failure_message = "expected #{expected} +/- (< #{delta}), got #{actual}"
        matcher.description = "be close to #{expected} (within +- #{delta})"
        (actual - expected).abs < delta
      end
    end
  end
end
