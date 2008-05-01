require File.dirname(__FILE__) + '/../../spec_helper.rb'
module Spec
  module Matchers
    describe BeClose do
      it "should match when value == target" do
        BeClose.new(5.0, 0.5).matches?(5.0).should be_true
      end
      it "should match when value < (target + delta)" do
        BeClose.new(5.0, 0.5).matches?(5.49).should be_true
      end
      it "should match when value > (target - delta)" do
        BeClose.new(5.0, 0.5).matches?(4.51).should be_true
      end
      it "should not match when value == (target - delta)" do
        BeClose.new(5.0, 0.5).matches?(4.5).should be_false
      end
      it "should not match when value < (target - delta)" do
        BeClose.new(5.0, 0.5).matches?(4.49).should be_false
      end
      it "should not match when value == (target + delta)" do
        BeClose.new(5.0, 0.5).matches?(5.5).should be_false
      end
      it "should not match when value > (target + delta)" do
        BeClose.new(5.0, 0.5).matches?(5.51).should be_false
      end
      it "should provide a useful failure message" do
        #given
          matcher = BeClose.new(5.0, 0.5)
        #when
          matcher.matches?(5.51)
        #then
          matcher.failure_message.should == "expected 5.0 +/- (< 0.5), got 5.51"
      end
      it "should describe itself" do
        BeClose.new(5.0, 0.5).description.should == "be close to 5.0 (within +- 0.5)"
      end
    end
  end
end
