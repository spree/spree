require File.dirname(__FILE__) + '/../../spec_helper'

module Spec
  module Mocks
    describe Mock do

      before(:each) do
        @mock = mock("test mock")
      end
      
      after(:each) do
        @mock.rspec_reset
      end
      
      it "should report line number of expectation of unreceived message" do
        expected_error_line = __LINE__; @mock.should_receive(:wont_happen).with("x", 3)
        begin
          @mock.rspec_verify
          violated
        rescue MockExpectationError => e
          # NOTE - this regexp ended w/ $, but jruby adds extra info at the end of the line
          e.backtrace[0].should match(/#{File.basename(__FILE__)}:#{expected_error_line}/)
        end
      end
      
      it "should pass when not receiving message specified as not to be received" do
        @mock.should_not_receive(:not_expected)
        @mock.rspec_verify
      end
      
      it "should pass when receiving message specified as not to be received with different args" do
        @mock.should_not_receive(:message).with("unwanted text")
        @mock.should_receive(:message).with("other text")
        @mock.message "other text"
        @mock.rspec_verify
      end
      
      it "should fail when receiving message specified as not to be received" do
        @mock.should_not_receive(:not_expected)
        lambda {
          @mock.not_expected
          violated
        }.should raise_error(MockExpectationError, "Mock 'test mock' expected :not_expected with (no args) 0 times, but received it once")
      end
      
      it "should fail when receiving message specified as not to be received with args" do
        @mock.should_not_receive(:not_expected).with("unexpected text")
        lambda {
          @mock.not_expected("unexpected text")
          violated
        }.should raise_error(MockExpectationError, "Mock 'test mock' expected :not_expected with (\"unexpected text\") 0 times, but received it once")
      end
      
      it "should pass when receiving message specified as not to be received with wrong args" do
        @mock.should_not_receive(:not_expected).with("unexpected text")
        @mock.not_expected "really unexpected text"
        @mock.rspec_verify
      end
      
      it "should allow block to calculate return values" do
        @mock.should_receive(:something).with("a","b","c").and_return { |a,b,c| c+b+a }
        @mock.something("a","b","c").should == "cba"
        @mock.rspec_verify
      end
      
      it "should allow parameter as return value" do
        @mock.should_receive(:something).with("a","b","c").and_return("booh")
        @mock.something("a","b","c").should == "booh"
        @mock.rspec_verify
      end
      
      it "should return nil if no return value set" do
        @mock.should_receive(:something).with("a","b","c")
        @mock.something("a","b","c").should be_nil
        @mock.rspec_verify
      end
      
      it "should raise exception if args don't match when method called" do
        @mock.should_receive(:something).with("a","b","c").and_return("booh")
        lambda {
          @mock.something("a","d","c")
          violated
        }.should raise_error(MockExpectationError, "Mock 'test mock' expected :something with (\"a\", \"b\", \"c\") but received it with (\"a\", \"d\", \"c\")")
      end
           
      it "should raise exception if args don't match when method called even when the method is stubbed" do
        @mock.stub!(:something)
        @mock.should_receive(:something).with("a","b","c")
        lambda {
          @mock.something("a","d","c")
          @mock.rspec_verify
        }.should raise_error(MockExpectationError, "Mock 'test mock' expected :something with (\"a\", \"b\", \"c\") but received it with (\"a\", \"d\", \"c\")")
      end
           
      it "should raise exception if args don't match when method called even when using null_object" do
        @mock = mock("test mock", :null_object => true)
        @mock.should_receive(:something).with("a","b","c")
        lambda {
          @mock.something("a","d","c")
          @mock.rspec_verify
        }.should raise_error(MockExpectationError, "Mock 'test mock' expected :something with (\"a\", \"b\", \"c\") but received it with (\"a\", \"d\", \"c\")")
      end
           
      it "should fail if unexpected method called" do
        lambda {
          @mock.something("a","b","c")
          violated
        }.should raise_error(MockExpectationError, "Mock 'test mock' received unexpected message :something with (\"a\", \"b\", \"c\")")
      end
        
      it "should use block for expectation if provided" do
        @mock.should_receive(:something) do | a, b |
          a.should == "a"
          b.should == "b"
          "booh"
        end
        @mock.something("a", "b").should == "booh"
        @mock.rspec_verify
      end
        
      it "should fail if expectation block fails" do
        @mock.should_receive(:something) {| bool | bool.should be_true}
        lambda {
          @mock.something false
        }.should raise_error(MockExpectationError, /Mock 'test mock' received :something but passed block failed with: expected true, got false/)
      end
        
      it "should fail right away when method defined as never is received" do
        @mock.should_receive(:not_expected).never
        lambda {
          @mock.not_expected
        }.should raise_error(MockExpectationError, "Mock 'test mock' expected :not_expected with (no args) 0 times, but received it once")
      end
      
      it "should eventually fail when method defined as never is received" do
        @mock.should_receive(:not_expected).never
        lambda {
          @mock.not_expected
        }.should raise_error(MockExpectationError, "Mock 'test mock' expected :not_expected with (no args) 0 times, but received it once")
      end
    
      it "should raise when told to" do
        @mock.should_receive(:something).and_raise(RuntimeError)
        lambda do
          @mock.something
        end.should raise_error(RuntimeError)
      end
       
      it "should raise passed an Exception instance" do
        error = RuntimeError.new("error message")
        @mock.should_receive(:something).and_raise(error)
        lambda {
          @mock.something
        }.should raise_error(RuntimeError, "error message")
      end
      
      it "should raise RuntimeError with passed message" do
        @mock.should_receive(:something).and_raise("error message")
        lambda {
          @mock.something
        }.should raise_error(RuntimeError, "error message")
      end
       
      it "should not raise when told to if args dont match" do
        @mock.should_receive(:something).with(2).and_raise(RuntimeError)
        lambda {
          @mock.something 1
        }.should raise_error(MockExpectationError)
      end
       
      it "should throw when told to" do
        @mock.should_receive(:something).and_throw(:blech)
        lambda {
          @mock.something
        }.should throw_symbol(:blech)
      end
      
      it "should raise when explicit return and block constrained" do
        lambda {
          @mock.should_receive(:fruit) do |colour|
            :strawberry
          end.and_return :apple
        }.should raise_error(AmbiguousReturnError)
      end
      
      it "should ignore args on any args" do
        @mock.should_receive(:something).at_least(:once).with(any_args)
        @mock.something
        @mock.something 1
        @mock.something "a", 2
        @mock.something [], {}, "joe", 7
        @mock.rspec_verify
      end
      
      it "should fail on no args if any args received" do
        @mock.should_receive(:something).with(no_args())
        lambda {
          @mock.something 1
        }.should raise_error(MockExpectationError, "Mock 'test mock' expected :something with (no args) but received it with (1)")
      end
    
      it "should fail when args are expected but none are received" do
        @mock.should_receive(:something).with(1)
        lambda {
          @mock.something
        }.should raise_error(MockExpectationError, "Mock 'test mock' expected :something with (1) but received it with (no args)")
      end
    
      it "should return value from block by default" do
        @mock.stub!(:method_that_yields).and_yield
        @mock.method_that_yields { :returned_obj }.should == :returned_obj
        @mock.rspec_verify
      end
    
      it "should yield 0 args to blocks that take a variable number of arguments" do
        @mock.should_receive(:yield_back).with(no_args()).once.and_yield
        a = nil
        @mock.yield_back {|*a|}
        a.should == []
        @mock.rspec_verify
      end
      
      it "should yield 0 args multiple times to blocks that take a variable number of arguments" do
        @mock.should_receive(:yield_back).once.with(no_args()).once.and_yield.
                                                                    and_yield
        a = nil
        b = []
        @mock.yield_back {|*a| b << a}
        b.should == [ [], [] ]
        @mock.rspec_verify
      end
      
      it "should yield one arg to blocks that take a variable number of arguments" do
        @mock.should_receive(:yield_back).with(no_args()).once.and_yield(99)
        a = nil
        @mock.yield_back {|*a|}
        a.should == [99]
        @mock.rspec_verify
      end
      
      it "should yield one arg 3 times consecutively to blocks that take a variable number of arguments" do
        @mock.should_receive(:yield_back).once.with(no_args()).once.and_yield(99).
                                                                    and_yield(43).
                                                                    and_yield("something fruity")
        a = nil
        b = []
        @mock.yield_back {|*a| b << a}
        b.should == [[99], [43], ["something fruity"]]
        @mock.rspec_verify
      end
      
      it "should yield many args to blocks that take a variable number of arguments" do
        @mock.should_receive(:yield_back).with(no_args()).once.and_yield(99, 27, "go")
        a = nil
        @mock.yield_back {|*a|}
        a.should == [99, 27, "go"]
        @mock.rspec_verify
      end
    
      it "should yield many args 3 times consecutively to blocks that take a variable number of arguments" do
        @mock.should_receive(:yield_back).once.with(no_args()).once.and_yield(99, :green, "go").
                                                                    and_yield("wait", :amber).
                                                                    and_yield("stop", 12, :red)
        a = nil
        b = []
        @mock.yield_back {|*a| b << a}
        b.should == [[99, :green, "go"], ["wait", :amber], ["stop", 12, :red]]
        @mock.rspec_verify
      end
      
      it "should yield single value" do
        @mock.should_receive(:yield_back).with(no_args()).once.and_yield(99)
        a = nil
        @mock.yield_back {|a|}
        a.should == 99
        @mock.rspec_verify
      end
      
      it "should yield single value 3 times consecutively" do
        @mock.should_receive(:yield_back).once.with(no_args()).once.and_yield(99).
                                                                    and_yield(43).
                                                                    and_yield("something fruity")
        a = nil
        b = []
        @mock.yield_back {|a| b << a}
        b.should == [99, 43, "something fruity"]
        @mock.rspec_verify
      end
      
      it "should yield two values" do
        @mock.should_receive(:yield_back).with(no_args()).once.and_yield('wha', 'zup')
        a, b = nil
        @mock.yield_back {|a,b|}
        a.should == 'wha'
        b.should == 'zup'
        @mock.rspec_verify
      end
      
      it "should yield two values 3 times consecutively" do
        @mock.should_receive(:yield_back).once.with(no_args()).once.and_yield('wha', 'zup').
                                                                    and_yield('not', 'down').
                                                                    and_yield(14, 65)
        a, b = nil
        c = []
        @mock.yield_back {|a,b| c << [a, b]}
        c.should == [['wha', 'zup'], ['not', 'down'], [14, 65]]
        @mock.rspec_verify
      end
      
      it "should fail when calling yielding method with wrong arity" do
        @mock.should_receive(:yield_back).with(no_args()).once.and_yield('wha', 'zup')
        lambda {
          @mock.yield_back {|a|}
        }.should raise_error(MockExpectationError, "Mock 'test mock' yielded |\"wha\", \"zup\"| to block with arity of 1")
      end
      
      it "should fail when calling yielding method consecutively with wrong arity" do
        @mock.should_receive(:yield_back).once.with(no_args()).once.and_yield('wha', 'zup').
                                                                    and_yield('down').
                                                                    and_yield(14, 65)
        lambda {
          a, b = nil
          c = []
          @mock.yield_back {|a,b| c << [a, b]}
        }.should raise_error(MockExpectationError, "Mock 'test mock' yielded |\"down\"| to block with arity of 2")
      end
      
      it "should fail when calling yielding method without block" do
        @mock.should_receive(:yield_back).with(no_args()).once.and_yield('wha', 'zup')
        lambda {
          @mock.yield_back
        }.should raise_error(MockExpectationError, "Mock 'test mock' asked to yield |[\"wha\", \"zup\"]| but no block was passed")
      end
      
      it "should be able to mock send" do
        @mock.should_receive(:send).with(any_args)
        @mock.send 'hi'
        @mock.rspec_verify
      end
      
      it "should be able to raise from method calling yielding mock" do
        @mock.should_receive(:yield_me).and_yield 44
        
        lambda {
          @mock.yield_me do |x|
            raise "Bang"
          end
        }.should raise_error(StandardError, "Bang")
      
        @mock.rspec_verify
      end
      
      it "should clear expectations after verify" do
        @mock.should_receive(:foobar)
        @mock.foobar
        @mock.rspec_verify
        lambda {
          @mock.foobar
        }.should raise_error(MockExpectationError, "Mock 'test mock' received unexpected message :foobar with (no args)")
      end
      
      it "should restore objects to their original state on rspec_reset" do
        mock = mock("this is a mock")
        mock.should_receive(:blah)
        mock.rspec_reset
        mock.rspec_verify #should throw if reset didn't work
      end
    
      it "should work even after method_missing starts raising NameErrors instead of NoMethodErrors" do
        # Object#method_missing throws either NameErrors or NoMethodErrors.
        #
        # On a fresh ruby program Object#method_missing: 
        #  * raises a NoMethodError when called directly
        #  * raises a NameError when called indirectly
        #
        # Once Object#method_missing has been called at least once (on any object)
        # it starts behaving differently: 
        #  * raises a NameError when called directly
        #  * raises a NameError when called indirectly
        #
        # There was a bug in Mock#method_missing that relied on the fact
        # that calling Object#method_missing directly raises a NoMethodError.
        # This example tests that the bug doesn't exist anymore.
        
        
        # Ensures that method_missing always raises NameErrors.
        a_method_that_doesnt_exist rescue
        
        
        @mock.should_receive(:foobar)
        @mock.foobar
        @mock.rspec_verify
                
        lambda { @mock.foobar }.should_not raise_error(NameError)
        lambda { @mock.foobar }.should raise_error(MockExpectationError)
      end
    
      it "should temporarily replace a method stub on a mock" do
        @mock.stub!(:msg).and_return(:stub_value)
        @mock.should_receive(:msg).with(:arg).and_return(:mock_value)
        @mock.msg(:arg).should equal(:mock_value)
        @mock.msg.should equal(:stub_value)
        @mock.msg.should equal(:stub_value)
        @mock.rspec_verify
      end
    
      it "should temporarily replace a method stub on a non-mock" do
        non_mock = Object.new
        non_mock.stub!(:msg).and_return(:stub_value)
        non_mock.should_receive(:msg).with(:arg).and_return(:mock_value)
        non_mock.msg(:arg).should equal(:mock_value)
        non_mock.msg.should equal(:stub_value)
        non_mock.msg.should equal(:stub_value)
        non_mock.rspec_verify
      end
      
      it "should assign stub return values" do
        mock = Mock.new('name', :message => :response)
        mock.message.should == :response
      end
      
    end
    
    describe "a mock message receiving a block" do
      before(:each) do
        @mock = mock("mock")
        @calls = 0
      end
      
      def add_call
        @calls = @calls + 1
      end
      
      it "should call the block after #should_receive" do
        @mock.should_receive(:foo) { add_call }
    
        @mock.foo
    
        @calls.should == 1
      end
    
      it "should call the block after #once" do
        @mock.should_receive(:foo).once { add_call }
    
        @mock.foo
    
        @calls.should == 1
      end
    
      it "should call the block after #twice" do
        @mock.should_receive(:foo).twice { add_call }
    
        @mock.foo
        @mock.foo
    
        @calls.should == 2
      end
    
      it "should call the block after #times" do
        @mock.should_receive(:foo).exactly(10).times { add_call }
        
        (1..10).each { @mock.foo }
    
        @calls.should == 10
      end
    
      it "should call the block after #any_number_of_times" do
        @mock.should_receive(:foo).any_number_of_times { add_call }
        
        (1..7).each { @mock.foo }
    
        @calls.should == 7
      end
    
      it "should call the block after #ordered" do
        @mock.should_receive(:foo).ordered { add_call }
        @mock.should_receive(:bar).ordered { add_call }
        
        @mock.foo
        @mock.bar
    
        @calls.should == 2
      end
    end
    
    describe 'string representation generated by #to_s' do
      it 'should not contain < because that might lead to invalid HTML in some situations' do
        mock = mock("Dog")
        valid_html_str = "#{mock}"
        valid_html_str.should_not include('<')
      end
    end
  end
end
