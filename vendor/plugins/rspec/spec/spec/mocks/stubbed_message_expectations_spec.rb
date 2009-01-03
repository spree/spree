require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Mocks
    describe "Example with stubbed and then called message" do
      it "should fail if the message is expected and then subsequently not called again" do
        mock_obj = mock("mock", :msg => nil)
        mock_obj.msg
        mock_obj.should_receive(:msg)
        lambda { mock_obj.rspec_verify }.should raise_error(Spec::Mocks::MockExpectationError)
      end
    end
  end
end