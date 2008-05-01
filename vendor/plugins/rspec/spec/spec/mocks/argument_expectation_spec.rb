require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Mocks
    describe ArgumentExpectation do
      it "should consider an object that responds to #matches? and #description to be a matcher" do
        argument_expecatation = Spec::Mocks::ArgumentExpectation.new([])
        obj = mock("matcher")
        obj.should_receive(:respond_to?).with(:matches?).and_return(true)
        obj.should_receive(:respond_to?).with(:description).and_return(true)
        argument_expecatation.is_matcher?(obj).should be_true
      end

      it "should NOT consider an object that only responds to #matches? to be a matcher" do
        argument_expecatation = Spec::Mocks::ArgumentExpectation.new([])
        obj = mock("matcher")
        obj.should_receive(:respond_to?).with(:matches?).and_return(true)
        obj.should_receive(:respond_to?).with(:description).and_return(false)
        argument_expecatation.is_matcher?(obj).should be_false
      end
    end
  end
end
