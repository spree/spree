module Spec
  module Matchers
    class RaiseError #:nodoc:
      def initialize(error_or_message=Exception, message=nil, &block)
        @block = block
        case error_or_message
        when String, Regexp
          @expected_error, @expected_message = Exception, error_or_message
        else
          @expected_error, @expected_message = error_or_message, message
        end
      end

      def matches?(proc)
        @raised_expected_error = false
        @with_expected_message = false
        @eval_block = false
        @eval_block_passed = false
        begin
          proc.call
        rescue @expected_error => @actual_error
          @raised_expected_error = true
          @with_expected_message = verify_message
        rescue Exception => @actual_error
          # This clause should be empty, but rcov will not report it as covered
          # unless something (anything) is executed within the clause
          rcov_error_report = "http://eigenclass.org/hiki.rb?rcov-0.8.0"
        end

        unless negative_expectation?
          eval_block if @raised_expected_error && @with_expected_message && @block
        end
      ensure
        return (@raised_expected_error && @with_expected_message) ? (@eval_block ? @eval_block_passed : true) : false
      end
      
      def eval_block
        @eval_block = true
        begin
          @block[@actual_error]
          @eval_block_passed = true
        rescue Exception => err
          @actual_error = err
        end
      end

      def verify_message
        case @expected_message
        when nil
          return true
        when Regexp
          return @expected_message =~ @actual_error.message
        else
          return @expected_message == @actual_error.message
        end
      end
      
      def failure_message
        if @eval_block
          return @actual_error.message
        else
          return "expected #{expected_error}#{actual_error}"
        end
      end

      def negative_failure_message
        "expected no #{expected_error}#{actual_error}"
      end
      
      def description
        "raise #{expected_error}"
      end
      
      private
        def expected_error
          case @expected_message
          when nil
            @expected_error
          when Regexp
            "#{@expected_error} with message matching #{@expected_message.inspect}"
          else
            "#{@expected_error} with #{@expected_message.inspect}"
          end
        end

        def actual_error
          @actual_error.nil? ? " but nothing was raised" : ", got #{@actual_error.inspect}"
        end
        
        def negative_expectation?
          # YES - I'm a bad person... help me find a better way - ryand
          caller.first(3).find { |s| s =~ /should_not/ }
        end
    end
    
    # :call-seq:
    #   should raise_error()
    #   should raise_error(NamedError)
    #   should raise_error(NamedError, String)
    #   should raise_error(NamedError, Regexp)
    #   should raise_error() { |error| ... }
    #   should raise_error(NamedError) { |error| ... }
    #   should raise_error(NamedError, String) { |error| ... }
    #   should raise_error(NamedError, Regexp) { |error| ... }
    #   should_not raise_error()
    #   should_not raise_error(NamedError)
    #   should_not raise_error(NamedError, String)
    #   should_not raise_error(NamedError, Regexp)
    #
    # With no args, matches if any error is raised.
    # With a named error, matches only if that specific error is raised.
    # With a named error and messsage specified as a String, matches only if both match.
    # With a named error and messsage specified as a Regexp, matches only if both match.
    # Pass an optional block to perform extra verifications on the exception matched
    #
    # == Examples
    #
    #   lambda { do_something_risky }.should raise_error
    #   lambda { do_something_risky }.should raise_error(PoorRiskDecisionError)
    #   lambda { do_something_risky }.should raise_error(PoorRiskDecisionError) { |error| error.data.should == 42 }
    #   lambda { do_something_risky }.should raise_error(PoorRiskDecisionError, "that was too risky")
    #   lambda { do_something_risky }.should raise_error(PoorRiskDecisionError, /oo ri/)
    #
    #   lambda { do_something_risky }.should_not raise_error
    #   lambda { do_something_risky }.should_not raise_error(PoorRiskDecisionError)
    #   lambda { do_something_risky }.should_not raise_error(PoorRiskDecisionError, "that was too risky")
    #   lambda { do_something_risky }.should_not raise_error(PoorRiskDecisionError, /oo ri/)
    def raise_error(error=Exception, message=nil, &block)
      Matchers::RaiseError.new(error, message, &block)
    end
  end
end
