require File.dirname(__FILE__) + '/../../../spec_helper.rb'
require 'spec/runner/formatter/progress_bar_formatter'

module Spec
  module Runner
    module Formatter
      describe ProgressBarFormatter do
        before(:each) do
          @io = StringIO.new
          @options = mock('options')
          @options.stub!(:dry_run).and_return(false)
          @options.stub!(:colour).and_return(false)
          @formatter = ProgressBarFormatter.new(@options, @io)
        end

        it "should produce line break on start dump" do
          @formatter.start_dump
          @io.string.should eql("\n")
        end

        it "should produce standard summary without pending when pending has a 0 count" do
          @formatter.dump_summary(3, 2, 1, 0)
          @io.string.should eql("\nFinished in 3 seconds\n\n2 examples, 1 failure\n")
        end
        
        it "should produce standard summary" do
          example_group = ExampleGroup.describe("example_group") do
            specify "example" do
            end
          end
          example = example_group.examples.first
          @formatter.example_pending(example, "message")
          @io.rewind
          @formatter.dump_summary(3, 2, 1, 1)
          @io.string.should eql(%Q|
Finished in 3 seconds

2 examples, 1 failure, 1 pending
|)
        end

        it "should push green dot for passing spec" do
          @io.should_receive(:tty?).and_return(true)
          @options.should_receive(:colour).and_return(true)
          @formatter.example_passed("spec")
          @io.string.should == "\e[32m.\e[0m"
        end

        it "should push red F for failure spec" do
          @io.should_receive(:tty?).and_return(true)
          @options.should_receive(:colour).and_return(true)
          @formatter.example_failed("spec", 98, Reporter::Failure.new("c s", Spec::Expectations::ExpectationNotMetError.new))
          @io.string.should eql("\e[31mF\e[0m")
        end

        it "should push magenta F for error spec" do
          @io.should_receive(:tty?).and_return(true)
          @options.should_receive(:colour).and_return(true)
          @formatter.example_failed("spec", 98, Reporter::Failure.new("c s", RuntimeError.new))
          @io.string.should eql("\e[35mF\e[0m")
        end

        it "should push blue F for fixed pending spec" do
          @io.should_receive(:tty?).and_return(true)
          @options.should_receive(:colour).and_return(true)
          @formatter.example_failed("spec", 98, Reporter::Failure.new("c s", Spec::Example::PendingExampleFixedError.new))
          @io.string.should eql("\e[34mF\e[0m")
        end

        it "should push nothing on start" do
          @formatter.start(4)
          @io.string.should eql("")
        end

        it "should ensure two ':' in the first backtrace" do
          backtrace = ["/tmp/x.rb:1", "/tmp/x.rb:2", "/tmp/x.rb:3"]
          @formatter.format_backtrace(backtrace).should eql(<<-EOE.rstrip)
/tmp/x.rb:1:
/tmp/x.rb:2:
/tmp/x.rb:3:
EOE

          backtrace = ["/tmp/x.rb:1: message", "/tmp/x.rb:2", "/tmp/x.rb:3"]
          @formatter.format_backtrace(backtrace).should eql(<<-EOE.rstrip)
/tmp/x.rb:1: message
/tmp/x.rb:2:
/tmp/x.rb:3:
EOE
        end
        
        it "should dump pending" do
          example_group = ExampleGroup.describe("example_group") do
            specify "example" do
            end
          end
          example = example_group.examples.first
          @formatter.example_pending(example, "message")
          @formatter.dump_pending
          @io.string.should =~ /Pending\:\nexample_group example \(message\)\n/
        end
      end
      
      describe "ProgressBarFormatter outputting to custom out" do
        before(:each) do
          @out = mock("out")
          @options = mock('options')
          @out.stub!(:puts)
          @formatter = ProgressBarFormatter.new(@options, @out)
          @formatter.class.send :public, :output_to_tty?
        end

        after(:each) do
          @formatter.class.send :protected, :output_to_tty?
        end

        it "should not throw NoMethodError on output_to_tty?" do
          @out.should_receive(:tty?).and_raise(NoMethodError)
          @formatter.output_to_tty?.should be_false
        end
      end

      describe ProgressBarFormatter, "dry run" do
        before(:each) do
          @io = StringIO.new
          options = mock('options')
          options.stub!(:dry_run).and_return(true)
          @formatter = ProgressBarFormatter.new(options, @io)
        end
      
        it "should not produce summary on dry run" do
          @formatter.dump_summary(3, 2, 1, 0)
          @io.string.should eql("")
        end
      end
    end
  end
end
