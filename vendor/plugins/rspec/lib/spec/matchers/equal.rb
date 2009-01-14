module Spec
  module Matchers
  
    # :call-seq:
    #   should equal(expected)
    #   should_not equal(expected)
    #
    # Passes if actual and expected are the same object (object identity).
    #
    # See http://www.ruby-doc.org/core/classes/Object.html#M001057 for more information about equality in Ruby.
    #
    # == Examples
    #
    #   5.should equal(5) #Fixnums are equal
    #   "5".should_not equal("5") #Strings that look the same are not the same object
    def equal(expected)
      simple_matcher do |actual, matcher|
        matcher.failure_message          = "expected #{expected.inspect}, got #{actual.inspect} (using .equal?)", expected, actual
        matcher.negative_failure_message = "expected #{actual.inspect} not to equal #{expected.inspect} (using .equal?)", expected, actual
        matcher.description              = "equal #{expected.inspect}"
        actual.equal?(expected)
      end
    end
  end
end
