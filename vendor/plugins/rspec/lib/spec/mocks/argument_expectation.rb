module Spec
  module Mocks
    
    class ArgumentExpectation
      attr_reader :args
      
      def initialize(args, &block)
        @args = args
        @constraints_block = block
        
        if ArgumentConstraints::AnyArgsConstraint === args.first
          @match_any_args = true
        elsif ArgumentConstraints::NoArgsConstraint === args.first
          @constraints = []
        else
          @constraints = args.collect {|arg| constraint_for(arg)}
        end
      end
      
      def constraint_for(arg)
        return ArgumentConstraints::MatcherConstraint.new(arg)   if is_matcher?(arg)
        return ArgumentConstraints::RegexpConstraint.new(arg) if arg.is_a?(Regexp)
        return ArgumentConstraints::EqualityProxy.new(arg)
      end
      
      def is_matcher?(obj)
        return obj.respond_to?(:matches?) && obj.respond_to?(:description)
      end
      
      def args_match?(given_args)
        match_any_args? || constraints_block_matches?(given_args) || constraints_match?(given_args)
      end
      
      def constraints_block_matches?(given_args)
        @constraints_block ? @constraints_block.call(*given_args) : nil
      end
      
      def constraints_match?(given_args)
        @constraints == given_args
      end
      
      def match_any_args?
        @match_any_args
      end
      
    end
    
  end
end
