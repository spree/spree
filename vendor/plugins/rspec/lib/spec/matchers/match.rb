module Spec
  module Matchers
    
    # :call-seq:
    #   should match(regexp)
    #   should_not match(regexp)
    #
    # Given a Regexp, passes if actual =~ regexp
    #
    # == Examples
    #
    #   email.should match(/^([^\s]+)((?:[-a-z0-9]+\.)+[a-z]{2,})$/i)
    def match(regexp)
      simple_matcher do |actual, matcher|
        matcher.failure_message          = "expected #{actual.inspect} to match #{regexp.inspect}", regexp, actual
        matcher.negative_failure_message = "expected #{actual.inspect} not to match #{regexp.inspect}", regexp, actual
        matcher.description              = "match #{regexp.inspect}"
        actual =~ regexp
      end
    end
  end
end
