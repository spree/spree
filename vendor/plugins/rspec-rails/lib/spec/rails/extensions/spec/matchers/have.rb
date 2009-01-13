require 'spec/matchers/have'

module Spec #:nodoc:
  module Matchers #:nodoc:
    class Have #:nodoc:
      alias_method :__original_failure_message, :failure_message
      def failure_message
        return "expected #{relativities[@relativity]}#{@expected} errors on :#{@args[0]}, got #{@given}" if @collection_name == :errors_on
        return "expected #{relativities[@relativity]}#{@expected} error on :#{@args[0]}, got #{@given}" if @collection_name == :error_on
        return __original_failure_message
      end
      
      alias_method :__original_description, :description
      def description
        return "should have #{relativities[@relativity]}#{@expected} errors on :#{@args[0]}" if @collection_name == :errors_on
        return "should have #{relativities[@relativity]}#{@expected} error on :#{@args[0]}" if @collection_name == :error_on
        return __original_description
      end
    end
  end
end
