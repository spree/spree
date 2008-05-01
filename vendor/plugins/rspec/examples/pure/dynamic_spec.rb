require File.dirname(__FILE__) + '/spec_helper'

describe "Some integers" do
  (1..10).each do |n|
    it "The root of #{n} square should be #{n}" do
      Math.sqrt(n*n).should == n
    end
  end
end
