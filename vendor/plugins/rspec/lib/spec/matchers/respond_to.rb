module Spec
  module Matchers
    
    class RespondTo #:nodoc:
      def initialize(*names)
        @names = names
        @expected_arity = nil
        @names_not_responded_to = []
      end
      
      def matches?(actual)
        @actual = actual
        @names.each do |name|
          @names_not_responded_to << name unless actual.respond_to?(name) && matches_arity?(actual, name)
        end
        return @names_not_responded_to.empty?
      end
      
      def failure_message
        "expected #{@actual.inspect} to respond to #{@names_not_responded_to.collect {|name| name.inspect }.join(', ')}#{with_arity}"
      end
      
      def negative_failure_message
        "expected #{@actual.inspect} not to respond to #{@names.collect {|name| name.inspect }.join(', ')}"
      end
      
      def description
        # Ruby 1.9 returns the same thing for array.to_s as array.inspect, so just use array.inspect here
        "respond to #{pp_names}#{with_arity}"
      end
      
      def with(n)
        @expected_arity = n
        self
      end
      
      def argument
        self
      end
      alias :arguments :argument
      
    private
      
      def matches_arity?(actual, name)
        @expected_arity.nil?? true : @expected_arity == actual.method(name).arity 
      end
      
      def with_arity
        @expected_arity.nil?? "" :
          " with #{@expected_arity} argument#{@expected_arity == 1 ? '' : 's'}"
      end
      
      def pp_names
        @names.length == 1 ? "##{@names.first}" : @names.inspect
      end
    end
    
    # :call-seq:
    #   should respond_to(*names)
    #   should_not respond_to(*names)
    #
    # Matches if the target object responds to all of the names
    # provided. Names can be Strings or Symbols.
    #
    # == Examples
    # 
    def respond_to(*names)
      Matchers::RespondTo.new(*names)
    end
  end
end
