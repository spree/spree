require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Mocks
    describe "calling :should_receive with an options hash" do
      it "should report the file and line submitted with :expected_from" do
        begin
          mock = Spec::Mocks::Mock.new("a mock")
          mock.should_receive(:message, :expected_from => "/path/to/blah.ext:37")
          mock.rspec_verify
        rescue => e
        ensure
          e.backtrace.to_s.should =~ /\/path\/to\/blah.ext:37/m
        end
      end

      it "should use the message supplied with :message" do
        lambda {
          m = Spec::Mocks::Mock.new("a mock")
          m.should_receive(:message, :message => "recebi nada")
          m.rspec_verify
        }.should raise_error("recebi nada")
      end
      
      it "should use the message supplied with :message after a similar stub" do
        lambda {
          m = Spec::Mocks::Mock.new("a mock")
          m.stub!(:message)
          m.should_receive(:message, :message => "from mock")
          m.rspec_verify
        }.should raise_error("from mock")
      end
    end
  end
end
