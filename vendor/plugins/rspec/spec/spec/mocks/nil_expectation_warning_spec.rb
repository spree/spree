require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Mocks

    describe "an expectation set on nil" do
      
      it "should issue a warning with file and line number information" do
        expected_warning = %r%An expectation of :foo was set on nil. Called from #{__FILE__}:#{__LINE__+3}(:in `block \(2 levels\) in <module:Mocks>')?. Use allow_message_expectations_on_nil to disable warnings.%
        Kernel.should_receive(:warn).with(expected_warning)

        nil.should_receive(:foo)
        nil.foo
      end
      
      it "should issue a warning when the expectation is negative" do
        Kernel.should_receive(:warn)

        nil.should_not_receive(:foo)
      end
      
      it "should not issue a warning when expectations are set to be allowed" do
        allow_message_expectations_on_nil
        Kernel.should_not_receive(:warn)
        
        nil.should_receive(:foo)
        nil.should_not_receive(:bar)
        nil.foo
      end

    end
    
    describe "#allow_message_expectations_on_nil" do
      
      it "should not effect subsequent examples" do
        example_group = Class.new(ExampleGroup)
        example_group.it("when called in one example that doesn't end up setting an expectation on nil") do
                        allow_message_expectations_on_nil
                      end
        example_group.it("should not effect the next exapmle ran") do
                        Kernel.should_receive(:warn)
                        nil.should_receive(:foo)
                        nil.foo
                      end
                              
        example_group.run(Spec::Runner.options).should be_true
                  
      end

    end
    
  end
end
