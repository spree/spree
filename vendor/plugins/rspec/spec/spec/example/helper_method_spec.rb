require File.dirname(__FILE__) + '/../../spec_helper'

# This was added to prove that http://rspec.lighthouseapp.com/projects/5645/tickets/211
# was fixed in ruby 1.9.1

module HelperMethodExample
  describe "a helper method" do
    def helper_method
      "received call"
    end
  
    it "is available to examples in the same group" do
      helper_method.should == "received call"
    end
    
    describe "from a nested group" do
      it "is available to examples in a nested group" do
        helper_method.should == "received call"
      end
    end
    
  end
end

