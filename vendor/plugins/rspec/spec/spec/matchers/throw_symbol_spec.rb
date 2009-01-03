require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Matchers
    describe ThrowSymbol do
      describe "with no args" do
        before(:each) { @matcher = ThrowSymbol.new }
      
        it "should match if any Symbol is thrown" do
          @matcher.matches?(lambda{ throw :sym }).should be_true
        end
        it "should match if any Symbol is thrown with an arg" do
          @matcher.matches?(lambda{ throw :sym, "argument" }).should be_true
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
          
      describe "with a symbol" do
        before(:each) { @matcher = ThrowSymbol.new(:sym) }
      
        it "should match if correct Symbol is thrown" do
          @matcher.matches?(lambda{ throw :sym }).should be_true
        end
        it "should match if correct Symbol is thrown with an arg" do
          @matcher.matches?(lambda{ throw :sym, "argument" }).should be_true
        end
        it "should not match if no Symbol is thrown" do
          @matcher.matches?(lambda{ }).should be_false
        end
        it "should not match if correct Symbol is thrown" do
          @matcher.matches?(lambda{ throw :other_sym }).should be_false
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

      describe "with a symbol and an arg" do
        before(:each) { @matcher = ThrowSymbol.new(:sym, "a") }
    
        it "should match if correct Symbol and args are thrown" do
          @matcher.matches?(lambda{ throw :sym, "a" }).should be_true
        end
        it "should not match if nothing is thrown" do
          @matcher.matches?(lambda{ }).should be_false
        end
        it "should not match if other Symbol is thrown" do
          @matcher.matches?(lambda{ throw :other_sym, "a" }).should be_false
        end
        it "should not match if no arg is thrown" do
          @matcher.matches?(lambda{ throw :sym }).should be_false
        end
        it "should not match if wrong arg is thrown" do
          @matcher.matches?(lambda{ throw :sym, "b" }).should be_false
        end
        it "should provide a failure message when no Symbol is thrown" do
          @matcher.matches?(lambda{})
          @matcher.failure_message.should == %q[expected :sym with "a" but nothing was thrown]
        end
        it "should provide a failure message when wrong Symbol is thrown" do
          @matcher.matches?(lambda{ throw :other_sym })
          @matcher.failure_message.should == %q[expected :sym with "a", got :other_sym]
        end
        it "should provide a negative failure message" do
          @matcher.matches?(lambda{ throw :sym })
          @matcher.negative_failure_message.should == %q[expected :sym with "a" not to be thrown]
        end
        it "should only match NameErrors raised by uncaught throws" do
          @matcher.matches?(lambda{ sym }).should be_false
        end
      end
    end
  end
end
