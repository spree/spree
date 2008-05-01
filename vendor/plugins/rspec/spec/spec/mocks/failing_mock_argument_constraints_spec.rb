require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Mocks
    describe "failing MockArgumentConstraints" do
      before(:each) do
        @mock = mock("test mock")
        @reporter = Mock.new("reporter", :null_object => true)
      end
      
      after(:each) do
        @mock.rspec_reset
      end

      it "should reject non boolean" do
        @mock.should_receive(:random_call).with(boolean())
        lambda do
          @mock.random_call("false")
        end.should raise_error(MockExpectationError)
      end

      it "should reject non numeric" do
        @mock.should_receive(:random_call).with(an_instance_of(Numeric))
        lambda do
          @mock.random_call("1")
        end.should raise_error(MockExpectationError)
      end
      
      it "should reject non string" do
        @mock.should_receive(:random_call).with(an_instance_of(String))
        lambda do
          @mock.random_call(123)
        end.should raise_error(MockExpectationError)
      end
      
      it "should reject goose when expecting a duck" do
        @mock.should_receive(:random_call).with(duck_type(:abs, :div))
        lambda { @mock.random_call("I don't respond to :abs or :div") }.should raise_error(MockExpectationError)
      end

      it "should fail if regexp does not match submitted string" do
        @mock.should_receive(:random_call).with(/bcd/)
        lambda { @mock.random_call("abc") }.should raise_error(MockExpectationError)
      end
      
      it "should fail if regexp does not match submitted regexp" do
        @mock.should_receive(:random_call).with(/bcd/)
        lambda { @mock.random_call(/bcde/) }.should raise_error(MockExpectationError)
      end
      
      it "should fail for a hash w/ wrong values" do
        @mock.should_receive(:random_call).with(:a => "b", :c => "d")
        lambda do
          @mock.random_call(:a => "b", :c => "e")
        end.should raise_error(MockExpectationError, /Mock 'test mock' expected :random_call with \(\{(:a=>\"b\", :c=>\"d\"|:c=>\"d\", :a=>\"b\")\}\) but received it with \(\{(:a=>\"b\", :c=>\"e\"|:c=>\"e\", :a=>\"b\")\}\)/)
      end
      
      it "should fail for a hash w/ wrong keys" do
        @mock.should_receive(:random_call).with(:a => "b", :c => "d")
        lambda do
          @mock.random_call("a" => "b", "c" => "d")
        end.should raise_error(MockExpectationError, /Mock 'test mock' expected :random_call with \(\{(:a=>\"b\", :c=>\"d\"|:c=>\"d\", :a=>\"b\")\}\) but received it with \(\{(\"a\"=>\"b\", \"c\"=>\"d\"|\"c\"=>\"d\", \"a\"=>\"b\")\}\)/)
      end
      
      it "should match against a Matcher" do
        lambda do
          @mock.should_receive(:msg).with(equal(3))
          @mock.msg(37)
        end.should raise_error(MockExpectationError, "Mock 'test mock' expected :msg with (equal 3) but received it with (37)")
      end
      
      it "should fail no_args with one arg" do
        lambda do
          @mock.should_receive(:msg).with(no_args)
          @mock.msg(37)
        end.should raise_error(MockExpectationError, "Mock 'test mock' expected :msg with (no args) but received it with (37)")
      end
    end
      
    describe "failing deprecated MockArgumentConstraints" do
      before(:each) do
        @mock = mock("test mock")
        @reporter = Mock.new("reporter", :null_object => true)
        Kernel.stub!(:warn)
      end

      after(:each) do
        @mock.rspec_reset
      end

      it "should reject non boolean" do
        @mock.should_receive(:random_call).with(:boolean)
        lambda do
          @mock.random_call("false")
        end.should raise_error(MockExpectationError)
      end
      
      it "should reject non numeric" do
        @mock.should_receive(:random_call).with(:numeric)
        lambda do
          @mock.random_call("1")
        end.should raise_error(MockExpectationError)
      end
      
      it "should reject non string" do
        @mock.should_receive(:random_call).with(:string)
        lambda do
          @mock.random_call(123)
        end.should raise_error(MockExpectationError)
      end
      

    end
  end
end
