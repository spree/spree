require File.dirname(__FILE__) + '/spec_helper'

module HelperMethodExample
  describe "an example group with helper a method" do
    def helper_method
      "received call"
    end
  
    it "should make that method available to specs" do
      helper_method.should == "received call"
    end
  end
end

