require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Mocks
    describe "a mock acting as a NullObject" do
      before(:each) do
        @mock = Mock.new("null_object", :null_object => true)
      end

      it "should allow explicit expectation" do
        @mock.should_receive(:something)
        @mock.something
      end

      it "should fail verification when explicit exception not met" do
        lambda do
          @mock.should_receive(:something)
          @mock.rspec_verify
        end.should raise_error(MockExpectationError)
      end

      it "should ignore unexpected methods" do
        @mock.random_call("a", "d", "c")
        @mock.rspec_verify
      end

      it "should expected message with different args first" do
        @mock.should_receive(:message).with(:expected_arg)
        @mock.message(:unexpected_arg)
        @mock.message(:expected_arg)
      end

      it "should expected message with different args second" do
        @mock.should_receive(:message).with(:expected_arg)
        @mock.message(:expected_arg)
        @mock.message(:unexpected_arg)
      end
    end

    describe "#null_object?" do
      it "should default to false" do
        obj = mock('anything')
        obj.should_not be_null_object
      end
    end
    
    describe "#as_null_object" do
      it "should set the object to null_object" do
        obj = mock('anything').as_null_object
        obj.should be_null_object
      end
    end
  end
end
