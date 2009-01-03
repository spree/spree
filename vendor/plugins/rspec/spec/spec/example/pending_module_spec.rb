module Spec
  module Example
    describe Pending do
      
      it 'should raise an ExamplePendingError if no block is supplied' do
        lambda {
          pending "TODO"
        }.should raise_error(ExamplePendingError, /TODO/)
      end
      
      it 'should raise an ExamplePendingError if a supplied block fails as expected' do
        lambda {
          pending "TODO" do
            raise "oops"
          end
        }.should raise_error(ExamplePendingError, /TODO/)
      end
      
      it 'should raise an ExamplePendingError if a supplied block fails as expected with a mock' do
        lambda {
          pending "TODO" do
            m = mock('thing')
            m.should_receive(:foo)
            m.rspec_verify
          end
        }.should raise_error(ExamplePendingError, /TODO/)
      end
      
      it 'should raise a PendingExampleFixedError if a supplied block starts working' do
        lambda {
          pending "TODO" do
            # success!
          end
        }.should raise_error(PendingExampleFixedError, /TODO/)
      end
      
      it "should have the correct file and line number for pending given with a block which fails" do
        file = __FILE__
        line_number = __LINE__ + 2
        begin
          pending do
            raise
          end
        rescue => error
          error.pending_caller.should == "#{file}:#{line_number}"
        end
      end
      
      it "should have the correct file and line number for pending given with no block" do
        file = __FILE__
        line_number = __LINE__ + 2
        begin
          pending("TODO")
        rescue => error
          error.pending_caller.should == "#{file}:#{line_number}"
        end
      end
    end
    
    describe ExamplePendingError do
      it "should have the caller (from two calls from initialization)" do
        two_calls_ago = caller[0]
        ExamplePendingError.new("a message").pending_caller.should == two_calls_ago
      end
      
      it "should keep the trace information from initialization" do
        two_calls_ago = caller[0]
        obj = ExamplePendingError.new("a message")
        obj.pending_caller
        def another_caller(obj)
          obj.pending_caller
        end
        
        another_caller(obj).should == two_calls_ago
      end
      
      it "should have the message provided" do
        ExamplePendingError.new("a message").message.should == "a message"
      end

      it "should use a 'ExamplePendingError' as it's default message" do
        ExamplePendingError.new.message.should == "Spec::Example::ExamplePendingError"
      end
    end
    
    describe NotYetImplementedError do
      def rspec_root
        File.expand_path(__FILE__.gsub("/spec/spec/example/pending_module_spec.rb", "/lib"))
      end
      
      it "should have the root rspec path" do
        NotYetImplementedError::RSPEC_ROOT_LIB.should == rspec_root
      end
      
      it "should always have the error 'Not Yet Implemented'" do
        NotYetImplementedError.new([]).message.should == "Not Yet Implemented"
      end
      
      describe "pending_caller" do
        it "should select an element out of the backtrace" do
          error = NotYetImplementedError.new(["foo/bar.rb:18"])
          
          error.pending_caller.should == "foo/bar.rb:18"
        end
        
        it "should actually report the element from the backtrace" do
          error = NotYetImplementedError.new(["bar.rb:18"])
          
          error.pending_caller.should == "bar.rb:18"
        end
        
        it "should not use an element with the rspec root path" do
          error = NotYetImplementedError.new(["#{rspec_root}:8"])
          
          error.pending_caller.should be_nil
        end
        
        it "should select the first line in the backtrace which isn't in the rspec root" do
          error = NotYetImplementedError.new([
            "#{rspec_root}/foo.rb:2",
            "#{rspec_root}/foo/bar.rb:18",
            "path1.rb:22",
            "path2.rb:33"
          ])
          
          error.pending_caller.should == "path1.rb:22"
        end
        
        it "should cache the caller" do
          backtrace = mock('backtrace')
          backtrace.should_receive(:detect).once
          
          error = NotYetImplementedError.new(backtrace)
          error.pending_caller.should == error.pending_caller
        end
      end
    end
  end
end
