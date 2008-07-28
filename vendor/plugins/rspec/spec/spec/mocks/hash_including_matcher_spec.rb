require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Mocks
    describe HashIncludingConstraint do
      
      it "should match the same hash" do
        hash_including(:a => 1).matches?(:a => 1).should be_true
      end
      
      it "should not match a non-hash" do
        hash_including(:a => 1).matches?(1).should_not be_true
      end

      it "should match a hash with extra stuff" do
        hash_including(:a => 1).matches?(:a => 1, :b => 2).should be_true
      end
      
      it "should not match a hash with a missing key" do
        hash_including(:a => 1).matches?(:b => 2).should_not be_true
      end

      it "should not match a hash with an incorrect value" do
        hash_including(:a => 1, :b => 2).matches?(:a => 1, :b => 3).should_not be_true
      end

      it "should describe itself properly" do
        HashIncludingConstraint.new(:a => 1).description.should == "hash_including(:a=>1)"
      end      
    end
 end
end