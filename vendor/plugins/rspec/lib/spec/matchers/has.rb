module Spec
  module Matchers
    
    class Has #:nodoc:
      def initialize(sym, *args)
        @sym = sym
        @args = args
      end
      
      def matches?(target)
        @target = target
        begin
          return target.send(predicate, *@args)
        rescue => @error
          # This clause should be empty, but rcov will not report it as covered
          # unless something (anything) is executed within the clause
          rcov_error_report = "http://eigenclass.org/hiki.rb?rcov-0.8.0"
        end
        return false
      end
      
      def failure_message
        raise @error if @error
        "expected ##{predicate}(#{@args[0].inspect}) to return true, got false"
      end
      
      def negative_failure_message
        raise @error if @error
        "expected ##{predicate}(#{@args[0].inspect}) to return false, got true"
      end
      
      def description
        "have key #{@args[0].inspect}"
      end
      
      private
        def predicate
          "#{@sym.to_s.sub("have_","has_")}?".to_sym
        end
        
    end
 
  end
end
