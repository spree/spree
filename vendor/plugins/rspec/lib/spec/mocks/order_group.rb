module Spec
  module Mocks
    class OrderGroup
      def initialize error_generator
        @error_generator = error_generator
        @ordering = Array.new
      end
      
      def register(expectation)
        @ordering << expectation
      end
      
      def ready_for?(expectation)
        return @ordering.first == expectation
      end
      
      def consume
        @ordering.shift
      end
      
      def handle_order_constraint expectation
        return unless @ordering.include? expectation
        return consume if ready_for?(expectation)
        @error_generator.raise_out_of_order_error expectation.sym
      end
      
    end
  end
end
