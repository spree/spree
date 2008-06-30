module Spec
  module Rails
    module Matchers
    
      class HaveText  #:nodoc:

        def initialize(expected)
          @expected = expected
        end

        def matches?(response_or_text)
          @actual = response_or_text.respond_to?(:body) ? response_or_text.body : response_or_text
          return actual =~ expected if Regexp === expected
          return actual == expected unless Regexp === expected
        end
      
        def failure_message
          "expected #{expected.inspect}, got #{actual.inspect}"
        end
        
        def negative_failure_message
          "expected not to have text #{expected.inspect}"
        end
        
        def to_s
          "have text #{expected.inspect}"
        end
      
        private
          attr_reader :expected
          attr_reader :actual

      end

      # :call-seq:
      #   response.should have_text(expected)
      #   response.should_not have_text(expected)
      #
      # Accepts a String or a Regexp, matching a String using ==
      # and a Regexp using =~.
      #
      # If response_or_text has a #body, then that is used as to match against
      # else it uses response_or_text
      #
      # Use this instead of <tt>response.should have_tag()</tt>
      # when you want to match the whole string or whole body
      #
      # == Examples
      #
      #   response.should have_text("This is the expected text")
      def have_text(text)
        HaveText.new(text)
      end
    
    end
  end
end
