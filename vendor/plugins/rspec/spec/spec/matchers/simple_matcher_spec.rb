require File.dirname(__FILE__) + '/../../spec_helper'

module Spec
  module Matchers
    describe SimpleMatcher do
      it "should pass match arg to block" do
        actual = nil
        matcher = simple_matcher("message") do |given| actual = given end
        matcher.matches?("foo")
        actual.should == "foo"
      end
      
      it "should provide a stock failure message" do
        matcher = simple_matcher("thing") do end
        matcher.matches?("other")
        matcher.failure_message.should =~ /expected \"thing\" but got \"other\"/
      end
      
      it "should provide a stock negative failure message" do
        matcher = simple_matcher("thing") do end
        matcher.matches?("other")
        matcher.negative_failure_message.should =~ /expected not to get \"thing\", but got \"other\"/
      end
      
      it "should provide the given description" do
        matcher = simple_matcher("thing") do end
        matcher.description.should =="thing"
      end
      
      it "should fail if a wrapped 'should' fails" do
        matcher = simple_matcher("should fail") do
          2.should == 3
        end
        lambda do
          matcher.matches?("anything").should be_true
        end.should fail_with(/expected: 3/)
      end
    end
    
    describe "with arity of 2" do
      it "should provide the matcher so you can access its messages" do
        provided_matcher = nil
        matcher = simple_matcher("thing") do |given, matcher|
          provided_matcher = matcher
        end
        matcher.matches?("anything")
        provided_matcher.should equal(matcher)
      end
      
      it "should support a custom failure message" do
        matcher = simple_matcher("thing") do |given, matcher|
          matcher.failure_message = "custom message"
        end
        matcher.matches?("other")
        matcher.failure_message.should == "custom message"
      end

      it "should complain when asked for a failure message if you don't give it a description or a message" do
        matcher = simple_matcher do |given, matcher| end
        matcher.matches?("other")
        matcher.failure_message.should =~ /No description provided/
      end

      it "should support a custom negative failure message" do
        matcher = simple_matcher("thing") do |given, matcher|
          matcher.negative_failure_message = "custom message"
        end
        matcher.matches?("other")
        matcher.negative_failure_message.should == "custom message"
      end
      
      it "should complain when asked for a negative failure message if you don't give it a description or a message" do
        matcher = simple_matcher do |given, matcher| end
        matcher.matches?("other")
        matcher.negative_failure_message.should =~ /No description provided/
      end

      it "should support a custom description" do
        matcher = simple_matcher("thing") do |given, matcher|
          matcher.description = "custom message"
        end
        matcher.matches?("description")
        matcher.description.should == "custom message"
      end

      it "should tell you no description was provided when it doesn't receive one" do
        matcher = simple_matcher do end
        matcher.description.should =~ /No description provided/
      end
    end
    
  end
end