require File.dirname(__FILE__) + '/../../spec_helper'

module Spec
  module Example
    # describe Example do
    #   before(:each) do
    #     @example = Example.new "example" do
    #       foo
    #     end
    #   end
    #   
    #   it "should tell you its docstring" do
    #     @example.description.should == "example"
    #   end
    # 
    #   it "should execute its block in the context provided" do
    #     context = Class.new do
    #       def foo
    #         "foo"
    #       end
    #     end.new
    #     @example.run_in(context).should == "foo"
    #   end
    # end
    # 
    # describe Example, "#description" do
    #   it "should default to NO NAME when not passed anything when there are no matchers" do
    #     example = Example.new {}
    #     example.run_in(Object.new)
    #     example.description.should == "NO NAME"
    #   end
    # 
    #   it "should default to NO NAME description (Because of --dry-run) when passed nil and there are no matchers" do
    #     example = Example.new(nil) {}
    #     example.run_in(Object.new)
    #     example.description.should == "NO NAME"
    #   end
    # 
    #   it "should allow description to be overridden" do
    #     example = Example.new("Test description")
    #     example.description.should == "Test description"
    #   end
    # 
    #   it "should use description generated from matcher when there is no passed in description" do
    #     example = Example.new(nil) do
    #       1.should == 1
    #     end
    #     example.run_in(Object.new)
    #     example.description.should == "should == 1"
    #   end
    # end
  end
end
