require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Runner
    describe Options do
      before(:each) do
        @err = StringIO.new('')
        @out = StringIO.new('')
        @options = Options.new(@err, @out)
      end

      after(:each) do
        Spec::Expectations.differ = nil
      end

      describe "#examples" do
        it "should default to empty array" do
          @options.examples.should == []
        end
      end
      
      describe "#include_pattern" do
        it "should default to '**/*_spec.rb'" do
          @options.filename_pattern.should == "**/*_spec.rb"
        end
      end
      
      describe "#files_to_load" do
        
        it "should load files not following pattern if named explicitly" do
          file = File.expand_path(File.dirname(__FILE__) + "/resources/a_bar.rb")
          @options.files << file
          @options.files_to_load.should include(file)
        end
        
        describe "with default --pattern" do
          it "should load files named _spec.rb" do
            dir = File.expand_path(File.dirname(__FILE__) + "/resources/")
            @options.files << dir
            @options.files_to_load.should == ["#{dir}/a_spec.rb"]
          end
        end
        
        describe "with explicit pattern (single)" do
          before(:each) do
            @options.filename_pattern = "**/*_foo.rb"
          end
        
          it "should load files following pattern" do
            file = File.expand_path(File.dirname(__FILE__) + "/resources/a_foo.rb")
            @options.files << file
            @options.files_to_load.should include(file)
          end
        
          it "should load files in directories following pattern" do
            dir = File.expand_path(File.dirname(__FILE__) + "/resources")
            @options.files << dir
            @options.files_to_load.should include("#{dir}/a_foo.rb")
          end
        
          it "should not load files in directories not following pattern" do
            dir = File.expand_path(File.dirname(__FILE__) + "/resources")
            @options.files << dir
            @options.files_to_load.should_not include("#{dir}/a_bar.rb")
          end
        end
        
        describe "with explicit pattern (comma,separated,values)" do
          
          before(:each) do
            @options.filename_pattern = "**/*_foo.rb,**/*_bar.rb"
          end

          it "should support comma separated values" do
            dir = File.expand_path(File.dirname(__FILE__) + "/resources")
            @options.files << dir
            @options.files_to_load.should include("#{dir}/a_foo.rb")
            @options.files_to_load.should include("#{dir}/a_bar.rb")
          end
        
          it "should support comma separated values with spaces" do
            dir = File.expand_path(File.dirname(__FILE__) + "/resources")
            @options.files << dir
            @options.files_to_load.should include("#{dir}/a_foo.rb")
            @options.files_to_load.should include("#{dir}/a_bar.rb")
          end
        
        end
      
      end

      describe "#backtrace_tweaker" do
        it "should default to QuietBacktraceTweaker" do
          @options.backtrace_tweaker.class.should == QuietBacktraceTweaker
        end
      end

      describe "#dry_run" do
        it "should default to false" do
          @options.dry_run.should == false
        end
      end

      describe "#context_lines" do
        it "should default to 3" do
          @options.context_lines.should == 3
        end
      end

      describe "#parse_diff with nil" do
        before(:each) do
          @options.parse_diff nil
        end

        it "should make diff_format unified" do
          @options.diff_format.should == :unified
        end

        it "should set Spec::Expectations.differ to be a default differ" do
          Spec::Expectations.differ.class.should ==
            ::Spec::Expectations::Differs::Default
        end
      end

      describe "#parse_diff with 'unified'" do
        before(:each) do
          @options.parse_diff 'unified'
        end

        it "should make diff_format unified and uses default differ_class" do
          @options.diff_format.should == :unified
          @options.differ_class.should equal(Spec::Expectations::Differs::Default)
        end

        it "should set Spec::Expectations.differ to be a default differ" do
          Spec::Expectations.differ.class.should ==
            ::Spec::Expectations::Differs::Default
        end
      end

      describe "#parse_diff with 'context'" do
        before(:each) do
          @options.parse_diff 'context'
        end

        it "should make diff_format context and uses default differ_class" do
          @options.diff_format.should == :context
          @options.differ_class.should == Spec::Expectations::Differs::Default
        end

        it "should set Spec::Expectations.differ to be a default differ" do
          Spec::Expectations.differ.class.should ==
            ::Spec::Expectations::Differs::Default
        end
      end

      describe "#parse_diff with Custom::Differ" do
        before(:each) do
          @options.parse_diff 'Custom::Differ'
        end

        it "should use custom differ_class" do
          @options.diff_format.should == :custom
          @options.differ_class.should == Custom::Differ
          Spec::Expectations.differ.should be_instance_of(Custom::Differ)
        end

        it "should set Spec::Expectations.differ to be a default differ" do
          Spec::Expectations.differ.class.should ==
            ::Custom::Differ
        end
      end

      describe "#parse_diff with missing class name" do
        it "should raise error" do
          lambda { @options.parse_diff "Custom::MissingDiffer" }.should raise_error(NameError)
          @err.string.should match(/Couldn't find differ class Custom::MissingDiffer/n)
        end
      end

      describe "#parse_example" do
        it "with argument thats not a file path, sets argument as the example" do
          example = "something or other"
          File.file?(example).should == false
          @options.parse_example example
          @options.examples.should eql(["something or other"])
        end

        it "with argument that is a file path, sets examples to contents of the file" do
          example = "#{File.dirname(__FILE__)}/examples.txt"
          File.should_receive(:file?).with(example).and_return(true)
          file = StringIO.new("Sir, if you were my husband, I would poison your drink.\nMadam, if you were my wife, I would drink it.")
          File.should_receive(:open).with(example).and_return(file)

          @options.parse_example example
          @options.examples.should eql([
            "Sir, if you were my husband, I would poison your drink.",
              "Madam, if you were my wife, I would drink it."
          ])
        end
      end

      describe "#examples_should_not_be_run" do
        it "should cause #run_examples to return true and do nothing" do
          @options.examples_should_not_be_run
          ExampleGroupRunner.should_not_receive(:new)

          @options.run_examples.should be_true
        end
      end

      describe "#load_class" do
        it "should raise error when not class name" do
          lambda do
            @options.send(:load_class, 'foo', 'fruit', '--food')
          end.should raise_error('"foo" is not a valid class name')
        end
      end

      describe "#reporter" do
        it "returns a Reporter" do
          @options.reporter.should be_instance_of(Reporter)
          @options.reporter.options.should === @options
        end
      end

      describe "#add_example_group affecting passed in example_group" do
        it "runs all examples when options.examples is nil" do
          example_1_has_run = false
          example_2_has_run = false
          @example_group = Class.new(::Spec::Example::ExampleGroup).describe("Some Examples") do
            it "runs 1" do
              example_1_has_run = true
            end
            it "runs 2" do
              example_2_has_run = true
            end
          end

          @options.examples = nil

          @options.add_example_group @example_group
          @options.run_examples
          example_1_has_run.should be_true
          example_2_has_run.should be_true
        end

        it "keeps all example_definitions when options.examples is empty" do
          example_1_has_run = false
          example_2_has_run = false
          @example_group = Class.new(::Spec::Example::ExampleGroup).describe("Some Examples") do
            it "runs 1" do
              example_1_has_run = true
            end
            it "runs 2" do
              example_2_has_run = true
            end
          end

          @options.examples = []

          @options.add_example_group @example_group
          @options.run_examples
          example_1_has_run.should be_true
          example_2_has_run.should be_true
        end
      end

      describe "#add_example_group affecting example_group" do
        it "adds example_group when example_group has example_definitions and is not shared" do
          @example_group = Class.new(::Spec::Example::ExampleGroup).describe("Some Examples") do
            it "uses this example_group" do
            end
          end

          @options.number_of_examples.should == 0
          @options.add_example_group @example_group
          @options.number_of_examples.should == 1
          @options.example_groups.length.should == 1
        end
      end

      describe "#remove_example_group" do
        it "should remove the ExampleGroup from the list of ExampleGroups" do
          @example_group = Class.new(::Spec::Example::ExampleGroup).describe("Some Examples") do
          end
          @options.add_example_group @example_group
          @options.example_groups.should include(@example_group)

          @options.remove_example_group @example_group
          @options.example_groups.should_not include(@example_group)
        end
      end

      describe "#run_examples" do
        describe "when not given a custom runner" do
          it "should use the standard" do
            runner = ::Spec::Runner::ExampleGroupRunner.new(@options)
            ::Spec::Runner::ExampleGroupRunner.should_receive(:new).
            with(@options).
            and_return(runner)
            @options.user_input_for_runner = nil

            @options.run_examples
          end
        end

        describe "when given a custom runner" do
          it "should use the custom runner" do
            runner = Custom::ExampleGroupRunner.new(@options, nil)
            Custom::ExampleGroupRunner.should_receive(:new).
            with(@options, nil).
            and_return(runner)
            @options.user_input_for_runner = "Custom::ExampleGroupRunner"

            @options.run_examples
          end

          it "should use the custom runner with extra options" do
            runner = Custom::ExampleGroupRunner.new(@options, 'something')
            Custom::ExampleGroupRunner.should_receive(:new).
            with(@options, 'something').
            and_return(runner)
            @options.user_input_for_runner = "Custom::ExampleGroupRunner:something"

            @options.run_examples
          end
        end

        describe "when there are examples" do
          before(:each) do
            @example_group = Class.new(::Spec::Example::ExampleGroup)
            @options.add_example_group @example_group
            @options.formatters << Formatter::BaseTextFormatter.new(@options, @out)
          end

          it "runs the Examples and outputs the result" do
            @options.run_examples
            @out.string.should include("0 examples, 0 failures")
          end

          it "sets #examples_run? to true" do
            @options.examples_run?.should be_false
            @options.run_examples
            @options.examples_run?.should be_true
          end

          describe "and the suite passes" do
            before do
              @example_group.should_receive(:run).and_return(true)
            end

            it "invokes after_suite_parts with true" do
              success_result = nil
              @options.after_suite_parts << lambda do |success|
                success_result = success
              end
              
              @options.run_examples
              success_result.should be_true
            end
          end

          describe "and the suite fails" do
            before do
              @example_group.should_receive(:run).and_return(false)
            end

            it "invokes after_suite_parts with false" do
              success_result = nil
              @options.after_suite_parts << lambda do |success|
                success_result = success
              end

              @options.run_examples
              success_result.should be_false
            end
          end

          describe "when using heckle runner" do
            before(:each) do
              @heckle_runner_mock = mock("HeckleRunner")
              @options.heckle_runner = @heckle_runner_mock
            end
            
            it "should heckle" do
              @heckle_runner_mock.should_receive(:heckle_with)
              @options.run_examples
            end
            
            it "shouldn't heckle recursively" do
              heckled = false
              @heckle_runner_mock.should_receive(:heckle_with) {
                heckled.should == false
                heckled = true
                @options.run_examples
              }
              @options.run_examples
            end

            it "shouldn't load spec files twice" do
              example_runner = mock("ExampleGroupRunner")
              example_runner_inside_heckle = mock("ExampleGroupRunner inside Heckle")

              ExampleGroupRunner.should_receive(:new).twice.and_return(
                example_runner, example_runner_inside_heckle
              )

              example_runner.stub!(:run)
              example_runner.should_receive(:load_files)
              @heckle_runner_mock.stub!(:heckle_with).and_return { @options.run_examples }
              example_runner_inside_heckle.stub!(:run)
              example_runner_inside_heckle.should_not_receive(:load_files)

              @options.run_examples
            end
          end
        end

        describe "when there are no examples" do
          before(:each) do
            @options.formatters << Formatter::BaseTextFormatter.new(@options, @out)
          end

          it "does not run Examples and does not output a result" do
            @options.run_examples
            @out.string.should_not include("examples")
            @out.string.should_not include("failures")
          end

          it "sets #examples_run? to false" do
            @options.examples_run?.should be_false
            @options.run_examples
            @options.examples_run?.should be_false
          end

          it "invokes after_suite_parts with true" do
            success_result = nil
            @options.after_suite_parts << lambda do |success|
              success_result = success
            end

            @options.run_examples
            success_result.should be_true
          end
        end
      end
    end
  end
end
