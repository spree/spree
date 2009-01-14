require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Mocks
    describe "mock argument constraints", :shared => true do
      before(:each) do
        @mock = Mock.new("test mock")
        Kernel.stub!(:warn)
      end
      
      after(:each) do
        @mock.rspec_verify
      end
    end
    
    describe Methods, "handling argument constraints" do
      it_should_behave_like "mock argument constraints"

      it "should accept true as boolean()" do
        @mock.should_receive(:random_call).with(boolean())
        @mock.random_call(true)
      end

      it "should accept false as boolean()" do
        @mock.should_receive(:random_call).with(boolean())
        @mock.random_call(false)
      end

      it "should accept fixnum as an_instance_of(Numeric)" do
        @mock.should_receive(:random_call).with(an_instance_of(Numeric))
        @mock.random_call(1)
      end

      it "should accept float as an_instance_of(Numeric)" do
        @mock.should_receive(:random_call).with(an_instance_of(Numeric))
        @mock.random_call(1.5)
      end

      it "should accept string as anything()" do
        @mock.should_receive(:random_call).with("a", anything(), "c")
        @mock.random_call("a", "whatever", "c")
      end

      it "should match duck type with one method" do
        @mock.should_receive(:random_call).with(duck_type(:length))
        @mock.random_call([])
      end

      it "should match duck type with two methods" do
        @mock.should_receive(:random_call).with(duck_type(:abs, :div))
        @mock.random_call(1)
      end
      
      it "should match no args against any_args()" do
        @mock.should_receive(:random_call).with(any_args)
        @mock.random_call()
      end
      
      it "should match one arg against any_args()" do
        @mock.should_receive(:random_call).with(any_args)
        @mock.random_call("a string")
      end
      
      it "should match no args against no_args()" do
        @mock.should_receive(:random_call).with(no_args)
        @mock.random_call()
      end
      
      it "should match hash with hash_including same hash" do
        @mock.should_receive(:random_call).with(hash_including(:a => 1))
        @mock.random_call(:a => 1)
      end
        
    end

    describe Methods, "handling block constraints" do
      it_should_behave_like "mock argument constraints"
      
      it "should match arguments against RSpec expectations" do
        @mock.should_receive(:random_call).with {|arg1, arg2, arr, *rest|
          arg1.should == 5
          arg2.should have_at_least(3).characters
          arg2.should have_at_most(10).characters
          arr.map {|i| i * 2}.should == [2,4,6]
          rest.should == [:fee, "fi", 4]
        }
        @mock.random_call 5, "hello", [1,2,3], :fee, "fi", 4
      end
    end
    
    describe Methods, "handling non-constraint arguments" do
      
      before(:each) do
        @mock = Mock.new("test mock")
      end
      
      it "should match non special symbol (can be removed when deprecated symbols are removed)" do
        @mock.should_receive(:random_call).with(:some_symbol)
        @mock.random_call(:some_symbol)
      end

      it "should match string against regexp" do
        @mock.should_receive(:random_call).with(/bcd/)
        @mock.random_call("abcde")
      end

      it "should match regexp against regexp" do
        @mock.should_receive(:random_call).with(/bcd/)
        @mock.random_call(/bcd/)
      end
      
      it "should match against a hash submitted and received by value" do
        @mock.should_receive(:random_call).with(:a => "a", :b => "b")
        @mock.random_call(:a => "a", :b => "b")
      end
      
      it "should match against a hash submitted by reference and received by value" do
        opts = {:a => "a", :b => "b"}
        @mock.should_receive(:random_call).with(opts)
        @mock.random_call(:a => "a", :b => "b")
      end
      
      it "should match against a hash submitted by value and received by reference" do
        opts = {:a => "a", :b => "b"}
        @mock.should_receive(:random_call).with(:a => "a", :b => "b")
        @mock.random_call(opts)
      end
    end
  end
end
