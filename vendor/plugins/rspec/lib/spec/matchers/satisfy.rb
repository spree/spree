module Spec
  module Matchers
    
    class Satisfy #:nodoc:
      def initialize(&block)
        @block = block
      end
      
      def matches?(actual, &block)
        @block = block if block
        @actual = actual
        @block.call(actual)
      end
      
      def failure_message
        "expected #{@actual} to satisfy block"
      end

      def negative_failure_message
        "expected #{@actual} not to satisfy block"
      end
    end
    
    # :call-seq:
    #   should satisfy {}
    #   should_not satisfy {}
    #
    # Passes if the submitted block returns true. Yields target to the
    # block.
    #
    # Generally speaking, this should be thought of as a last resort when
    # you can't find any other way to specify the behaviour you wish to
    # specify.
    #
    # If you do find yourself in such a situation, you could always write
    # a custom matcher, which would likely make your specs more expressive.
    #
    # == Examples
    #
    #   5.should satisfy { |n|
    #     n > 3
    #   }
    def satisfy(&block)
      Matchers::Satisfy.new(&block)
    end
  end
end
