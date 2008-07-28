module Spec
  module Mocks
    module ArgumentConstraintMatchers
      
      # Shortcut for creating an instance of Spec::Mocks::DuckTypeArgConstraint
      def duck_type(*args)
        DuckTypeArgConstraint.new(*args)
      end

      def any_args
        AnyArgsConstraint.new
      end
      
      def anything
        AnyArgConstraint.new(nil)
      end
      
      def boolean
        BooleanArgConstraint.new(nil)
      end
      
      def hash_including(expected={})
        HashIncludingConstraint.new(expected)
      end
      
      def no_args
        NoArgsConstraint.new
      end
    end
  end
end
