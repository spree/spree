require File.dirname(__FILE__) + "/../../../spec_helper"

module Spec
  module Example
    module  AModule;  end
    class   AClass;   end

    describe "With", AModule do
      it "should have the described_type as 'AModule'" do
        self.class.described_module.should == AModule
      end
    end
    
    describe "With", AClass do
      it "should have the described_module as nil" do
        self.class.described_module.should be_nil
      end
    end
  end
end
