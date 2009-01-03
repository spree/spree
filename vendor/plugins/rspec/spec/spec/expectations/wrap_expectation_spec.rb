require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Matchers
    describe "wrap_expectation" do
      
      def stub_matcher
        @_stub_matcher ||= simple_matcher do
        end
      end
      
      def failing_matcher
        @_failing_matcher ||= simple_matcher do
          1.should == 2
        end
      end
      
      it "should return true if there is no error" do
        wrap_expectation stub_matcher do
        end.should be_true
      end
      
      it "should return false if there is an error" do
        wrap_expectation failing_matcher do
          raise "error"
        end.should be_false
      end
    end
  end
end