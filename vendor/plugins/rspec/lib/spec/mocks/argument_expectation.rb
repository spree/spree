module Spec
  module Mocks
  
    class MatcherConstraint
      def initialize(matcher)
        @matcher = matcher
      end
      
      def matches?(value)
        @matcher.matches?(value)
      end
    end
      
    class LiteralArgConstraint
      def initialize(literal)
        @literal_value = literal
      end
      
      def matches?(value)
        @literal_value == value
      end
    end
    
    class RegexpArgConstraint
      def initialize(regexp)
        @regexp = regexp
      end
      
      def matches?(value)
        return value =~ @regexp unless value.is_a?(Regexp)
        value == @regexp
      end
    end
    
    class AnyArgConstraint
      def initialize(ignore)
      end
      
      def ==(other)
        true
      end
      
      # TODO - need this?
      def matches?(value)
        true
      end
    end
    
    class AnyArgsConstraint
      def description
        "any args"
      end
    end
    
    class NoArgsConstraint
      def description
        "no args"
      end
      
      def ==(args)
        args == []
      end
    end
    
    class NumericArgConstraint
      def initialize(ignore)
      end
      
      def matches?(value)
        value.is_a?(Numeric)
      end
    end
    
    class BooleanArgConstraint
      def initialize(ignore)
      end
      
      def ==(value)
        matches?(value)
      end
      
      def matches?(value)
        return true if value.is_a?(TrueClass)
        return true if value.is_a?(FalseClass)
        false
      end
    end
    
    class StringArgConstraint
      def initialize(ignore)
      end
      
      def matches?(value)
        value.is_a?(String)
      end
    end
    
    class DuckTypeArgConstraint
      def initialize(*methods_to_respond_to)
        @methods_to_respond_to = methods_to_respond_to
      end
  
      def matches?(value)
        @methods_to_respond_to.all? { |sym| value.respond_to?(sym) }
      end
      
      def description
        "duck_type"
      end
    end

    class ArgumentExpectation
      attr_reader :args
      @@constraint_classes = Hash.new { |hash, key| LiteralArgConstraint}
      @@constraint_classes[:anything] = AnyArgConstraint
      @@constraint_classes[:numeric] = NumericArgConstraint
      @@constraint_classes[:boolean] = BooleanArgConstraint
      @@constraint_classes[:string] = StringArgConstraint
      
      def initialize(args)
        @args = args
        if [:any_args] == args
          @expected_params = nil
          warn_deprecated(:any_args.inspect, "any_args()")
        elsif args.length == 1 && args[0].is_a?(AnyArgsConstraint) then @expected_params = nil
        elsif [:no_args] == args
          @expected_params = []
          warn_deprecated(:no_args.inspect, "no_args()")
        elsif args.length == 1 && args[0].is_a?(NoArgsConstraint) then @expected_params = []
        else @expected_params = process_arg_constraints(args)
        end
      end
      
      def process_arg_constraints(constraints)
        constraints.collect do |constraint| 
          convert_constraint(constraint)
        end
      end
      
      def warn_deprecated(deprecated_method, instead)
        Kernel.warn "The #{deprecated_method} constraint is deprecated. Use #{instead} instead."
      end
      
      def convert_constraint(constraint)
        if [:anything, :numeric, :boolean, :string].include?(constraint)
          case constraint
          when :anything
            instead = "anything()"
          when :boolean
            instead = "boolean()"
          when :numeric
            instead = "an_instance_of(Numeric)"
          when :string
            instead = "an_instance_of(String)"
          end
          warn_deprecated(constraint.inspect, instead)
          return @@constraint_classes[constraint].new(constraint)
        end
        return MatcherConstraint.new(constraint) if is_matcher?(constraint)
        return RegexpArgConstraint.new(constraint) if constraint.is_a?(Regexp)
        return LiteralArgConstraint.new(constraint)
      end
      
      def is_matcher?(obj)
        return obj.respond_to?(:matches?) && obj.respond_to?(:description)
      end
      
      def check_args(args)
        return true if @expected_params.nil?
        return true if @expected_params == args
        return constraints_match?(args)
      end
      
      def constraints_match?(args)
        return false if args.length != @expected_params.length
        @expected_params.each_index { |i| return false unless @expected_params[i].matches?(args[i]) }
        return true
      end
  
    end
    
  end
end
