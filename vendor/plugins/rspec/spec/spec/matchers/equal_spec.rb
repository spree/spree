require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Matchers
    describe Equal do
      it "should match when actual.equal?(expected)" do
        Equal.new(1).matches?(1).should be_true
      end
      it "should not match when !actual.equal?(expected)" do
        Equal.new("1").matches?("1").should be_false
      end
      it "should describe itself" do
        matcher = Equal.new(1)
        matcher.description.should == "equal 1"
      end
      it "should provide message, expected and actual on #failure_message" do
        matcher = Equal.new("1")
        matcher.matches?(1)
        matcher.failure_message.should == ["expected \"1\", got 1 (using .equal?)", "1", 1]
      end
      it "should provide message, expected and actual on #negative_failure_message" do
        matcher = Equal.new(1)
        matcher.matches?(1)
        matcher.negative_failure_message.should == ["expected 1 not to equal 1 (using .equal?)", 1, 1]
      end
    end
  end
end
