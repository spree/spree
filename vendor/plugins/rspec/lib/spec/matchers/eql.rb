module Spec
  module Matchers
  
    # :call-seq:
    #   should eql(expected)
    #   should_not eql(expected)
    #
    # Passes if actual and expected are of equal value, but not necessarily the same object.
    #
    # See http://www.ruby-doc.org/core/classes/Object.html#M001057 for more information about equality in Ruby.
    #
    # == Examples
    #
    #   5.should eql(5)
    #   5.should_not eql(3)
    def eql(expected)
      simple_matcher do |actual, matcher|
        matcher.failure_message          = "expected #{expected.inspect}, got #{actual.inspect} (using .eql?)", expected, actual
        matcher.negative_failure_message = "expected #{actual.inspect} not to equal #{expected.inspect} (using .eql?)", expected, actual
        matcher.description              = "eql #{expected.inspect}"
        actual.eql?(expected)
      end
    end
  end
end
