module Spec
  module Matchers
    
    class Be #:nodoc:
      def initialize(*args)
        if args.empty?
          @expected = :satisfy_if
        else
          @expected = parse_expected(args.shift)
        end
        @args = args
        @comparison = ""
      end
      
      def matches?(actual)
        @actual = actual
        if handling_predicate?
          begin
            return @result = actual.__send__(predicate, *@args)
          rescue => predicate_error
            # This clause should be empty, but rcov will not report it as covered
            # unless something (anything) is executed within the clause
            rcov_error_report = "http://eigenclass.org/hiki.rb?rcov-0.8.0"
          end

          # This supports should_exist > target.exists? in the old world.
          # We should consider deprecating that ability as in the new world
          # you can't write "should exist" unless you have your own custom matcher.
          begin
            return @result = actual.__send__(present_tense_predicate, *@args)
          rescue
            raise predicate_error
          end
        else
          return match_or_compare
        end
      end
      
      def failure_message
        return "expected #{@comparison}#{expected}, got #{@actual.inspect}" unless handling_predicate?
        return "expected #{predicate}#{args_to_s} to return true, got #{@result.inspect}"
      end
      
      def negative_failure_message
        return "expected not #{expected}, got #{@actual.inspect}" unless handling_predicate?
        return "expected #{predicate}#{args_to_s} to return false, got #{@result.inspect}"
      end
      
      def expected
        return "if to be satisfied" if @expected == :satisfy_if
        return true if @expected == :true
        return false if @expected == :false
        return "nil" if @expected == :nil
        return @expected.inspect
      end
      
      def match_or_compare
        return @actual ? true : false if @expected == :satisfy_if
        return @actual == true if @expected == :true
        return @actual == false if @expected == :false
        return @actual.nil? if @expected == :nil
        return @actual < @expected if @less_than
        return @actual <= @expected if @less_than_or_equal
        return @actual >= @expected if @greater_than_or_equal
        return @actual > @expected if @greater_than
        return @actual == @expected if @double_equal
        return @actual === @expected if @triple_equal
        return @actual.equal?(@expected)
      end
      
      def ==(expected)
        @prefix = "be "
        @double_equal = true
        @comparison = "== "
        @expected = expected
        self
      end

      def ===(expected)
        @prefix = "be "
        @triple_equal = true
        @comparison = "=== "
        @expected = expected
        self
      end

      def <(expected)
        @prefix = "be "
        @less_than = true
        @comparison = "< "
        @expected = expected
        self
      end

      def <=(expected)
        @prefix = "be "
        @less_than_or_equal = true
        @comparison = "<= "
        @expected = expected
        self
      end

      def >=(expected)
        @prefix = "be "
        @greater_than_or_equal = true
        @comparison = ">= "
        @expected = expected
        self
      end

      def >(expected)
        @prefix = "be "
        @greater_than = true
        @comparison = "> "
        @expected = expected
        self
      end
      
      def description
        "#{prefix_to_sentence}#{comparison}#{expected_to_sentence}#{args_to_sentence}"
      end

      private
        def parse_expected(expected)
          if Symbol === expected
            @handling_predicate = true
            ["be_an_","be_a_","be_"].each do |prefix|
              if expected.starts_with?(prefix)
                @prefix = prefix
                return "#{expected.to_s.sub(@prefix,"")}".to_sym
              end
            end
          end
          @prefix = ""
          return expected
        end
        
        def handling_predicate?
          return false if [:true, :false, :nil].include?(@expected)
          return @handling_predicate
        end

        def predicate
          "#{@expected.to_s}?".to_sym
        end
        
        def present_tense_predicate
          "#{@expected.to_s}s?".to_sym
        end
        
        def args_to_s
          return "" if @args.empty?
          inspected_args = @args.collect{|a| a.inspect}
          return "(#{inspected_args.join(', ')})"
        end
        
        def comparison
          @comparison
        end
        
        def expected_to_sentence
          split_words(@expected)
        end
        
        def prefix_to_sentence
          split_words(@prefix)
        end

        def split_words(sym)
          sym.to_s.gsub(/_/,' ')
        end

        def args_to_sentence
          case @args.length
            when 0
              ""
            when 1
              " #{@args[0]}"
            else
              " #{@args[0...-1].join(', ')} and #{@args[-1]}"
          end
        end
        
    end
 
    # :call-seq:
    #   should be
    #   should be_true
    #   should be_false
    #   should be_nil
    #   should be_arbitrary_predicate(*args)
    #   should_not be_nil
    #   should_not be_arbitrary_predicate(*args)
    #
    # Given true, false, or nil, will pass if actual is
    # true, false or nil (respectively). Given no args means
    # the caller should satisfy an if condition (to be or not to be). 
    #
    # Predicates are any Ruby method that ends in a "?" and returns true or false.
    # Given be_ followed by arbitrary_predicate (without the "?"), RSpec will match
    # convert that into a query against the target object.
    #
    # The arbitrary_predicate feature will handle any predicate
    # prefixed with "be_an_" (e.g. be_an_instance_of), "be_a_" (e.g. be_a_kind_of)
    # or "be_" (e.g. be_empty), letting you choose the prefix that best suits the predicate.
    #
    # == Examples 
    #
    #   target.should be
    #   target.should be_true
    #   target.should be_false
    #   target.should be_nil
    #   target.should_not be_nil
    #
    #   collection.should be_empty #passes if target.empty?
    #   "this string".should be_an_intance_of(String)
    #
    #   target.should_not be_empty #passes unless target.empty?
    #   target.should_not be_old_enough(16) #passes unless target.old_enough?(16)
    def be(*args)
      Matchers::Be.new(*args)
    end
  end
end
