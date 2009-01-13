require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Runner
    describe Reporter do
      attr_reader :formatter_output, :options, :backtrace_tweaker, :formatter, :reporter, :example_group
      before(:each) do
        @formatter_output = StringIO.new
        @options = Options.new(StringIO.new, StringIO.new)
        @backtrace_tweaker = stub("backtrace tweaker", :tweak_backtrace => nil)
        options.backtrace_tweaker = backtrace_tweaker
        @formatter = ::Spec::Runner::Formatter::BaseTextFormatter.new(options, formatter_output)
        options.formatters << formatter
        @reporter = Reporter.new(options)
        @example_group = create_example_group("example_group")
        reporter.add_example_group example_group
      end

      def failure
        Mocks::ArgumentConstraints::DuckTypeConstraint.new(:header, :exception)
      end

      def create_example_group(description_text)
        example_group = Spec::Example::ExampleGroup.describe(description_text) do
          it "should do something" do
          end
        end
        example_group
      end

      it "should assign itself as the reporter to options" do
        options.reporter.should equal(@reporter)
      end

      it "should tell formatter when example_group is added" do
        formatter.should_receive(:add_example_group).with(example_group)
        reporter.add_example_group(example_group)
      end

      it "should handle multiple example_groups with same name" do
        formatter.should_receive(:add_example_group).exactly(3).times
        formatter.should_receive(:example_started).exactly(3).times
        formatter.should_receive(:example_passed).exactly(3).times
        formatter.should_receive(:start_dump)
        formatter.should_receive(:dump_pending)
        formatter.should_receive(:close).with(no_args)
        formatter.should_receive(:dump_summary).with(anything(), 3, 0, 0)
        reporter.add_example_group(create_example_group("example_group"))
        reporter.example_started("spec 1")
        reporter.example_finished("spec 1")
        reporter.add_example_group(create_example_group("example_group"))
        reporter.example_started("spec 2")
        reporter.example_finished("spec 2")
        reporter.add_example_group(create_example_group("example_group"))
        reporter.example_started("spec 3")
        reporter.example_finished("spec 3")
        reporter.dump
      end

      it "should handle multiple examples with the same name" do
        error=RuntimeError.new
        passing = ExampleGroup.new("example")
        failing = ExampleGroup.new("example")

        formatter.should_receive(:add_example_group).exactly(2).times
        formatter.should_receive(:example_passed).with(passing).exactly(2).times
        formatter.should_receive(:example_failed).with(failing, 1, failure)
        formatter.should_receive(:example_failed).with(failing, 2, failure)
        formatter.should_receive(:dump_failure).exactly(2).times
        formatter.should_receive(:start_dump)
        formatter.should_receive(:dump_pending)
        formatter.should_receive(:close).with(no_args)
        formatter.should_receive(:dump_summary).with(anything(), 4, 2, 0)
        backtrace_tweaker.should_receive(:tweak_backtrace).twice

        reporter.add_example_group(create_example_group("example_group"))
        reporter.example_finished(passing)
        reporter.example_finished(failing, error)

        reporter.add_example_group(create_example_group("example_group"))
        reporter.example_finished(passing)
        reporter.example_finished(failing, error)
        reporter.dump
      end

      it "should push stats to formatter even with no data" do
        formatter.should_receive(:start_dump)
        formatter.should_receive(:dump_pending)
        formatter.should_receive(:dump_summary).with(anything(), 0, 0, 0)
        formatter.should_receive(:close).with(no_args)
        reporter.dump
      end

      it "should push time to formatter" do
        formatter.should_receive(:start).with(5)
        formatter.should_receive(:start_dump)
        formatter.should_receive(:dump_pending)
        formatter.should_receive(:close).with(no_args)
        formatter.should_receive(:dump_summary) do |time, a, b|
          time.to_s.should match(/[0-9].[0-9|e|-]+/)
        end
        reporter.start(5)
        reporter.end
        reporter.dump
      end

      describe "reporting one passing example" do
        it "should tell formatter example passed" do
          formatter.should_receive(:example_passed)
          reporter.example_finished("example")
        end

        it "should not delegate to backtrace tweaker" do
          formatter.should_receive(:example_passed)
          backtrace_tweaker.should_not_receive(:tweak_backtrace)
          reporter.example_finished("example")
        end

        it "should account for passing example in stats" do
          formatter.should_receive(:example_passed)
          formatter.should_receive(:start_dump)
          formatter.should_receive(:dump_pending)
          formatter.should_receive(:dump_summary).with(anything(), 1, 0, 0)
          formatter.should_receive(:close).with(no_args)
          reporter.example_finished("example")
          reporter.dump
        end
      end

      describe "reporting one failing example" do
        it "should tell formatter that example failed" do
          example = example_group.it("should do something") {}
          formatter.should_receive(:example_failed)
          reporter.example_finished(example, RuntimeError.new)
        end

        it "should delegate to backtrace tweaker" do
          formatter.should_receive(:example_failed)
          backtrace_tweaker.should_receive(:tweak_backtrace)
          reporter.example_finished(ExampleGroup.new("example"), RuntimeError.new)
        end

        it "should account for failing example in stats" do
          example = ExampleGroup.new("example")
          formatter.should_receive(:example_failed).with(example, 1, failure)
          formatter.should_receive(:start_dump)
          formatter.should_receive(:dump_pending)
          formatter.should_receive(:dump_failure).with(1, anything())
          formatter.should_receive(:dump_summary).with(anything(), 1, 1, 0)
          formatter.should_receive(:close).with(no_args)
          reporter.example_finished(example, RuntimeError.new)
          reporter.dump
        end

      end

      describe "reporting one pending example (ExamplePendingError)" do
        before :each do
          @pending_error = Spec::Example::ExamplePendingError.new("reason")
          @pending_caller = @pending_error.pending_caller
        end
        
        it "should tell formatter example is pending" do
          example = ExampleGroup.new("example")
          formatter.should_receive(:example_pending).with(example, "reason", @pending_caller)
          formatter.should_receive(:add_example_group).with(example_group)
          reporter.add_example_group(example_group)
          reporter.example_finished(example, @pending_error)
        end

        it "should account for pending example in stats" do
          example = ExampleGroup.new("example")
          formatter.should_receive(:example_pending).with(example, "reason", @pending_caller)
          formatter.should_receive(:start_dump)
          formatter.should_receive(:dump_pending)
          formatter.should_receive(:dump_summary).with(anything(), 1, 0, 1)
          formatter.should_receive(:close).with(no_args)
          formatter.should_receive(:add_example_group).with(example_group)
          reporter.add_example_group(example_group)
          reporter.example_finished(example, @pending_error)
          reporter.dump
        end
        
        describe "to formatters which have example_pending's arity of 2 (which is now deprecated)" do
          before :each do
            Kernel.stub!(:warn).with(Spec::Runner::Reporter::EXAMPLE_PENDING_DEPRECATION_WARNING)
          
            @deprecated_formatter = Class.new(@formatter.class) do
              attr_reader :example_passed_to_method, :message_passed_to_method

              def example_pending(example_passed_to_method, message_passed_to_method)
                @example_passed_to_method = example_passed_to_method
                @message_passed_to_method = message_passed_to_method
              end
            end.new(options, formatter_output)
            
            options.formatters << @deprecated_formatter
          end
          
          it "should pass the correct example to the formatter" do
            example = ExampleGroup.new("example")
            reporter.add_example_group(example_group)
            reporter.example_finished(example, @pending_error)
            
            (@deprecated_formatter.example_passed_to_method == example).should be_true
          end
          
          it "should pass the correct pending error message to the formatter" do
            example = ExampleGroup.new("example")
            reporter.add_example_group(example_group)
            reporter.example_finished(example, @pending_error)
            
            @deprecated_formatter.message_passed_to_method.should ==  @pending_error.message
          end
          
          it "should raise a deprecation warning" do
            Kernel.should_receive(:warn).with(Spec::Runner::Reporter::EXAMPLE_PENDING_DEPRECATION_WARNING)
            
            example = ExampleGroup.new("example")
            reporter.add_example_group(example_group)
            reporter.example_finished(example, @pending_error)
          end
        end
      end

      describe "reporting one pending example (PendingExampleFixedError)" do
        it "should tell formatter pending example is fixed" do
          formatter.should_receive(:example_failed) do |name, counter, failure|
            failure.header.should == "'example_group should do something' FIXED"
          end
          formatter.should_receive(:add_example_group).with(example_group)
          reporter.add_example_group(example_group)
          reporter.example_finished(example_group.examples.first, Spec::Example::PendingExampleFixedError.new("reason"))
        end
      end
    end
  end
end
