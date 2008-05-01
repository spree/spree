require File.dirname(__FILE__) + '/../../spec_helper'

module Spec
  module Mocks

    describe "Mock ordering" do

      before do
        @mock = mock("test mock")
      end
      
      after do
        @mock.rspec_reset
      end

      it "should pass two calls in order" do
        @mock.should_receive(:one).ordered
        @mock.should_receive(:two).ordered
        @mock.one
        @mock.two
        @mock.rspec_verify
      end

      it "should pass three calls in order" do
        @mock.should_receive(:one).ordered
        @mock.should_receive(:two).ordered
        @mock.should_receive(:three).ordered
        @mock.one
        @mock.two
        @mock.three
        @mock.rspec_verify
      end

      it "should fail if second call comes first" do
        @mock.should_receive(:one).ordered
        @mock.should_receive(:two).ordered
        lambda do
          @mock.two
        end.should raise_error(MockExpectationError, "Mock 'test mock' received :two out of order")
      end

      it "should fail if third call comes first" do
        @mock.should_receive(:one).ordered
        @mock.should_receive(:two).ordered
        @mock.should_receive(:three).ordered
        @mock.one
        lambda do
          @mock.three
        end.should raise_error(MockExpectationError, "Mock 'test mock' received :three out of order")
      end
      
      it "should fail if third call comes second" do
        @mock.should_receive(:one).ordered
        @mock.should_receive(:two).ordered
        @mock.should_receive(:three).ordered
        @mock.one
        lambda do
          @mock.three
        end.should raise_error(MockExpectationError, "Mock 'test mock' received :three out of order")
      end

      it "should ignore order of non ordered calls" do
        @mock.should_receive(:ignored_0)
        @mock.should_receive(:ordered_1).ordered
        @mock.should_receive(:ignored_1)
        @mock.should_receive(:ordered_2).ordered
        @mock.should_receive(:ignored_2)
        @mock.should_receive(:ignored_3)
        @mock.should_receive(:ordered_3).ordered
        @mock.should_receive(:ignored_4)
        @mock.ignored_3
        @mock.ordered_1
        @mock.ignored_0
        @mock.ordered_2
        @mock.ignored_4
        @mock.ignored_2
        @mock.ordered_3
        @mock.ignored_1
        @mock.rspec_verify
      end
            
    end
  end
end
