require File.dirname(__FILE__) + "/../../../spec_helper"

module Spec
  module Example
    module AModuleAutomaticallyIncluded
      def call_method
        @method_called = true
        return "a string"
      end
      
      def method_called?
        @method_called ? true : false
      end
    end
    
    describe "Including modules in an example group" do
      describe AModuleAutomaticallyIncluded do
        before :each do
          Kernel.stub!(:warn)
        end
        
        it "should return the correct values" do
          self.method_called?.should be_false
          self.call_method.should eql("a string")
          self.method_called?.should be_true
        end
        
        it "should respond_to? the methods from the module" do
          self.should respond_to(:method_called?)
          self.should respond_to(:call_method)
        end
        
        it "should not respond_to? methods which do not come from the module (or are in Spec::ExampleGroup)" do
          self.should_not respond_to(:adsfadfadadf_a_method_which_does_not_exist)
        end
        
        it "should respond_to? a method in Spec::ExampleGroup" do
          self.should respond_to(:describe)
        end
        
        it "should issue a warning with Kernel.warn" do
          Kernel.should_receive(:warn)
          self.call_method
        end
        
        it "should issue a warning when the example calls the method which is automatically included" do
          Kernel.should_receive(:warn).with("Modules will no longer be automatically included in RSpec version 1.1.4.  Called from #{__FILE__}:#{__LINE__+1}")
          self.method_called?
        end
        
        it "should issue a warning with the correct file and line numbers" do
          Kernel.should_receive(:warn).with("Modules will no longer be automatically included in RSpec version 1.1.4.  Called from #{__FILE__}:#{__LINE__+1}")
          self.method_called?
        end
      end
      
      describe AModuleAutomaticallyIncluded, "which is also manually included" do
        include AModuleAutomaticallyIncluded
        
        before :each do
          Kernel.stub!(:warn)
        end
        
        it "should respond to the methods since it is included" do
          self.should respond_to(:method_called?)
          self.should respond_to(:call_method)
        end
        
        it "should not issue a warning, since the module is manually included" do
          Kernel.should_not_receive(:warn)
          self.method_called?
        end
      end
    end
  end
end
