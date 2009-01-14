require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Matchers
    describe "eql" do
      it "should match when actual.eql?(expected)" do
        eql(1).matches?(1).should be_true
      end
      it "should not match when !actual.eql?(expected)" do
        eql(1).matches?(2).should be_false
      end
      it "should describe itself" do
        matcher = eql(1)
        matcher.matches?(1)
        matcher.description.should == "eql 1"
      end
      it "should provide message, expected and actual on #failure_message" do
        matcher = eql("1")
        matcher.matches?(1)
        matcher.failure_message.should == ["expected \"1\", got 1 (using .eql?)", "1", 1]
      end
      it "should provide message, expected and actual on #negative_failure_message" do
        matcher = eql(1)
        matcher.matches?(1)
        matcher.negative_failure_message.should == ["expected 1 not to equal 1 (using .eql?)", 1, 1]
      end
    end
  end
end
