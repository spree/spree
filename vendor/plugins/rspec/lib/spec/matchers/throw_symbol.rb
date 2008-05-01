module Spec
  module Matchers
    
    class ThrowSymbol #:nodoc:
      def initialize(expected=nil)
        @expected = expected
        @actual = nil
      end
      
      def matches?(proc)
        begin
          proc.call
        rescue NameError => e
          raise e unless e.message =~ /uncaught throw/
          @actual = e.name.to_sym
        ensure
          if @expected.nil?
            return @actual.nil? ? false : true
          else
            return @actual == @expected
          end
        end
      end

      def failure_message
        if @actual
          "expected #{expected}, got #{@actual.inspect}"
        else
          "expected #{expected} but nothing was thrown"
        end
      end
      
      def negative_failure_message
        if @expected
          "expected #{expected} not to be thrown"
        else
          "expected no Symbol, got :#{@actual}"
        end
      end
      
      def description
        "throw #{expected}"
      end
      
      private
      
        def expected
          @expected.nil? ? "a Symbol" : @expected.inspect
        end
      
    end
 
    # :call-seq:
    #   should throw_symbol()
    #   should throw_symbol(:sym)
    #   should_not throw_symbol()
    #   should_not throw_symbol(:sym)
    #
    # Given a Symbol argument, matches if a proc throws the specified Symbol.
    #
    # Given no argument, matches if a proc throws any Symbol.
    #
    # == Examples
    #
    #   lambda { do_something_risky }.should throw_symbol
    #   lambda { do_something_risky }.should throw_symbol(:that_was_risky)
    #
    #   lambda { do_something_risky }.should_not throw_symbol
    #   lambda { do_something_risky }.should_not throw_symbol(:that_was_risky)
    def throw_symbol(sym=nil)
      Matchers::ThrowSymbol.new(sym)
    end
  end
end
