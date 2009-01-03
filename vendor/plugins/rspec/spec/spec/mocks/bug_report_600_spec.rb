require File.dirname(__FILE__) + '/../../spec_helper.rb'

module BugReport600
  class ExampleClass
    def self.method_that_uses_define_method
      define_method "defined_method" do |attributes|
        load_address(address, attributes)
      end
    end
  end
 
  describe "stubbing a class method" do
    it "should work" do
      ExampleClass.should_receive(:define_method).with("defined_method")
      ExampleClass.method_that_uses_define_method
    end

    it "should restore the original method" do
      ExampleClass.method_that_uses_define_method
    end
  end
end