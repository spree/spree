require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Runner
    describe CommandLine, ".run" do
      it_should_behave_like "sandboxed rspec_options"
      attr_reader :options, :err, :out
      before do
        @err = options.error_stream
        @out = options.output_stream
      end

      it "should run directory" do
        file = File.dirname(__FILE__) + '/../../../examples/pure'
        Spec::Runner::CommandLine.run(OptionParser.parse([file,"-p","**/*.rb"], @err, @out))

        @out.rewind
        @out.read.should =~ /\d+ examples, 0 failures, 3 pending/n
      end

      it "should run file" do
        file = File.dirname(__FILE__) + '/../../../failing_examples/predicate_example.rb'
        Spec::Runner::CommandLine.run(OptionParser.parse([file], @err, @out))

        @out.rewind
        @out.read.should =~ /2 examples, 1 failure/n
      end

      it "should raise when file does not exist" do
        file = File.dirname(__FILE__) + '/doesntexist'

        lambda {
          Spec::Runner::CommandLine.run(OptionParser.parse([file], @err, @out))
        }.should raise_error
      end

      it "should return true when in --generate-options mode" do
        # NOTE - this used to say /dev/null but jruby hangs on that for some reason
        Spec::Runner::CommandLine.run(
          OptionParser.parse(['--generate-options', '/tmp/foo'], @err, @out)
        ).should be_true
      end

      it "should dump even if Interrupt exception is occurred" do
        example_group = Class.new(::Spec::Example::ExampleGroup) do
          describe("example_group")
          it "no error" do
          end

          it "should interrupt" do
            raise Interrupt, "I'm interrupting"
          end
        end

        options = ::Spec::Runner::Options.new(@err, @out)
        ::Spec::Runner::Options.should_receive(:new).with(@err, @out).and_return(options)
        options.reporter.should_receive(:dump)
        options.add_example_group(example_group)

        Spec::Runner::CommandLine.run(OptionParser.parse([], @err, @out))
      end

      it "should heckle when options have heckle_runner" do
        example_group = Class.new(::Spec::Example::ExampleGroup).describe("example_group") do
          it "no error" do
          end
        end
        options = ::Spec::Runner::Options.new(@err, @out)
        ::Spec::Runner::Options.should_receive(:new).with(@err, @out).and_return(options)
        options.add_example_group example_group

        heckle_runner = mock("heckle_runner")
        heckle_runner.should_receive(:heckle_with)
        $rspec_mocks.__send__(:mocks).delete(heckle_runner)

        options.heckle_runner = heckle_runner
        options.add_example_group(example_group)

        Spec::Runner::CommandLine.run(OptionParser.parse([], @err, @out))
        heckle_runner.rspec_verify
      end

      it "should run examples backwards if options.reverse is true" do
        options = ::Spec::Runner::Options.new(@err, @out)
        ::Spec::Runner::Options.should_receive(:new).with(@err, @out).and_return(options)
        options.reverse = true

        b1 = Class.new(Spec::Example::ExampleGroup)
        b2 = Class.new(Spec::Example::ExampleGroup)

        b2.should_receive(:run).ordered
        b1.should_receive(:run).ordered

        options.add_example_group(b1)
        options.add_example_group(b2)

        Spec::Runner::CommandLine.run(OptionParser.parse([], @err, @out))
      end

      it "should pass its ExampleGroup to the reporter" do
        example_group = Class.new(::Spec::Example::ExampleGroup).describe("example_group") do
          it "should" do
          end
        end
        options = ::Spec::Runner::Options.new(@err, @out)
        options.add_example_group(example_group)

        ::Spec::Runner::Options.should_receive(:new).with(@err, @out).and_return(options)
        options.reporter.should_receive(:add_example_group).with(example_group)
        
        Spec::Runner::CommandLine.run(OptionParser.parse([], @err, @out))
      end

      it "runs only selected Examples when options.examples is set" do
        options = ::Spec::Runner::Options.new(@err, @out)
        ::Spec::Runner::Options.should_receive(:new).with(@err, @out).and_return(options)

        options.examples << "example_group should"
        should_has_run = false
        should_not_has_run = false
        example_group = Class.new(::Spec::Example::ExampleGroup).describe("example_group") do
          it "should" do
            should_has_run = true
          end
          it "should not" do
            should_not_has_run = true
          end
        end

        options.reporter.should_receive(:add_example_group).with(example_group)

        options.add_example_group example_group
        Spec::Runner::CommandLine.run(OptionParser.parse([], @err, @out))

        should_has_run.should be_true
        should_not_has_run.should be_false
      end

      it "sets Spec.run to true" do
        ::Spec.run = false
        ::Spec.should_not be_run
        Spec::Runner::CommandLine.run(OptionParser.parse([], @err, @out))
        ::Spec.should be_run
      end
    end
  end
end