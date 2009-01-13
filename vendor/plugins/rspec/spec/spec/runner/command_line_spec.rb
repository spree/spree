require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Runner
    describe CommandLine, ".run" do
      with_sandboxed_options do
        attr_reader :err, :out
        before do
          @err = options.error_stream
          @out = options.output_stream
        end
      
        it "should run directory" do
          file = File.dirname(__FILE__) + '/../../../examples/passing'
          run_with(OptionParser.parse([file,"-p","**/*_spec.rb,**/*_example.rb"], @err, @out))

          @out.rewind
          @out.read.should =~ /\d+ examples, 0 failures, 3 pending/n
        end

        it "should run file" do
          file = File.dirname(__FILE__) + '/../../../examples/failing/predicate_example.rb'
          run_with(OptionParser.parse([file], @err, @out))

          @out.rewind
          @out.read.should =~ /3 examples, 2 failures/n
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
          example_group = describe("example_group") do
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

          options.examples << "example group expected example"
          expected_example_was_run = false
          unexpected_example_was_run = false
          example_group = describe("example group") do
            it "expected example" do
              expected_example_was_run = true
            end
            it "unexpected example" do
              unexpected_example_was_run = true
            end
          end

          options.reporter.should_receive(:add_example_group).with(example_group)

          options.add_example_group example_group
          run_with(options)

          expected_example_was_run.should be_true
          unexpected_example_was_run.should be_false
        end
      end
    end
  end
end