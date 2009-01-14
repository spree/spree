module Spec
  module Matchers
    
    class ThrowSymbol #:nodoc:
      def initialize(expected_symbol = nil, expected_arg=nil)
        @expected_symbol = expected_symbol
        @expected_arg = expected_arg
        @caught_symbol = nil
      end
      
      def matches?(given_proc)
        begin
          if @expected_symbol.nil?
            given_proc.call
          else
            @caught_arg = catch :proc_did_not_throw_anything do
              catch @expected_symbol do
                given_proc.call
                throw :proc_did_not_throw_anything, :nothing_thrown
              end
            end
            @caught_symbol = @expected_symbol unless @caught_arg == :nothing_thrown
          end

        # Ruby 1.8 uses NameError with `symbol'
        # Ruby 1.9 uses ArgumentError with :symbol
        rescue NameError, ArgumentError => e
          raise e unless e.message =~ /uncaught throw (`|\:)([a-zA-Z0-9_]*)(')?/
          @caught_symbol = $2.to_sym

        ensure
          if @expected_symbol.nil?
            return !@caught_symbol.nil?
          else
            if @expected_arg.nil?
              return @caught_symbol == @expected_symbol
            else
              # puts [@caught_symbol, @expected_symbol].inspect
              # puts [@caught_arg, @expected_arg].inspect
              return @caught_symbol == @expected_symbol && @caught_arg == @expected_arg
            end
          end
        end
      end

      def failure_message
        if @caught_symbol
          "expected #{expected}, got #{@caught_symbol.inspect}"
        else
          "expected #{expected} but nothing was thrown"
        end
      end
      
      def negative_failure_message
        if @expected_symbol
          "expected #{expected} not to be thrown"
        else
          "expected no Symbol, got :#{@caught_symbol}"
        end
      end
      
      def description
        "throw #{expected}"
      end
      
      private
      
        def expected
          @expected_symbol.nil? ? "a Symbol" : "#{@expected_symbol.inspect}#{args}"
        end
        
        def args
          @expected_arg.nil? ? "" : " with #{@expected_arg.inspect}"
        end
      
    end
 
    # :call-seq:
    #   should throw_symbol()
    #   should throw_symbol(:sym)
    #   should throw_symbol(:sym, arg)
    #   should_not throw_symbol()
    #   should_not throw_symbol(:sym)
    #   should_not throw_symbol(:sym, arg)
    #
    # Given no argument, matches if a proc throws any Symbol.
    #
    # Given a Symbol, matches if the given proc throws the specified Symbol.
    #
    # Given a Symbol and an arg, matches if the given proc throws the
    # specified Symbol with the specified arg.
    #
    # == Examples
    #
    #   lambda { do_something_risky }.should throw_symbol
    #   lambda { do_something_risky }.should throw_symbol(:that_was_risky)
    #   lambda { do_something_risky }.should throw_symbol(:that_was_risky, culprit)
    #
    #   lambda { do_something_risky }.should_not throw_symbol
    #   lambda { do_something_risky }.should_not throw_symbol(:that_was_risky)
    #   lambda { do_something_risky }.should_not throw_symbol(:that_was_risky, culprit)
    def throw_symbol(sym=nil)
      Matchers::ThrowSymbol.new(sym)
    end
  end
end
