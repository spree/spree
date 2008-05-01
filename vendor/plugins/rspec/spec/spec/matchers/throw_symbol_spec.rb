require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Matchers
    describe ThrowSymbol, "(constructed with no Symbol)" do
      before(:each) { @matcher = ThrowSymbol.new }

      it "should match if any Symbol is thrown" do
        @matcher.matches?(lambda{ throw :sym }).should be_true
      end
      it "should not match if no Symbol is thrown" do
        @matcher.matches?(lambda{ }).should be_false
      end
      it "should provide a failure message" do
        @matcher.matches?(lambda{})
        @matcher.failure_message.should == "expected a Symbol but nothing was thrown"
      end
      it "should provide a negative failure message" do
        @matcher.matches?(lambda{ throw :sym})
        @matcher.negative_failure_message.should == "expected no Symbol, got :sym"
      end
    end
    
    describe ThrowSymbol, "(constructed with a Symbol)" do
      before(:each) { @matcher = ThrowSymbol.new(:sym) }
      
      it "should match if correct Symbol is thrown" do
        @matcher.matches?(lambda{ throw :sym }).should be_true
      end
      it "should not match if no Symbol is thrown" do
        @matcher.matches?(lambda{ }).should be_false
      end
      it "should not match if correct Symbol is thrown" do
        @matcher.matches?(lambda{ throw :other_sym }).should be_false
        @matcher.failure_message.should == "expected :sym, got :other_sym"
      end
      it "should provide a failure message when no Symbol is thrown" do
        @matcher.matches?(lambda{})
        @matcher.failure_message.should == "expected :sym but nothing was thrown"
      end
      it "should provide a failure message when wrong Symbol is thrown" do
        @matcher.matches?(lambda{ throw :other_sym })
        @matcher.failure_message.should == "expected :sym, got :other_sym"
      end
      it "should provide a negative failure message" do
        @matcher.matches?(lambda{ throw :sym })
        @matcher.negative_failure_message.should == "expected :sym not to be thrown"
      end
      it "should only match NameErrors raised by uncaught throws" do
        @matcher.matches?(lambda{ sym }).should be_false
      end
    end
  end
end
