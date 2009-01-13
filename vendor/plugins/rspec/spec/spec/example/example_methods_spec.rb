require File.dirname(__FILE__) + '/../../spec_helper'

module Spec
  module Example
    module ModuleThatIsReopened
    end

    module ExampleMethods
      include ModuleThatIsReopened
    end

    module ModuleThatIsReopened
      def module_that_is_reopened_method
      end
    end

    describe ExampleMethods do
      describe "with an included module that is reopened" do
        it "should have repoened methods" do
          method(:module_that_is_reopened_method).should_not be_nil
        end
      end

      describe "lifecycle" do
        with_sandboxed_options do
          with_sandboxed_config do
            before do
              @options.formatters << mock("formatter", :null_object => true)
              @options.backtrace_tweaker = mock("backtrace_tweaker", :null_object => true)
              @reporter = FakeReporter.new(@options)
              @options.reporter = @reporter
            
              ExampleGroup.before_all_parts.should == []
              ExampleGroup.before_each_parts.should == []
              ExampleGroup.after_each_parts.should == []
              ExampleGroup.after_all_parts.should == []
              def ExampleGroup.count
                @count ||= 0
                @count = @count + 1
                @count
              end
            end
          end

          after do
            ExampleGroup.instance_variable_set("@before_all_parts", [])
            ExampleGroup.instance_variable_set("@before_each_parts", [])
            ExampleGroup.instance_variable_set("@after_each_parts", [])
            ExampleGroup.instance_variable_set("@after_all_parts", [])
          end

          describe "eval_block" do
            before(:each) do
              @example_group = Class.new(ExampleGroup)
            end
          
            describe "with a given description" do
              it "should provide the given description" do
                @example = @example_group.it("given description") { 2.should == 2 }
                @example.eval_block
                @example.description.should == "given description"
              end
            end

            describe "with no given description" do
              it "should provide the generated description" do
                @example = @example_group.it { 2.should == 2 }
                @example.eval_block
                @example.description.should == "should == 2"
              end
            end
          
            describe "with no implementation" do
              it "should raise an NotYetImplementedError" do
                lambda {
                  @example = @example_group.it
                  @example.eval_block
                }.should raise_error(Spec::Example::NotYetImplementedError, "Not Yet Implemented")
              end
            
              def extract_error(&blk)
                begin
                  blk.call
                rescue Exception => e
                  return e
                end
              
                nil
              end
            
              it "should use the proper file and line number for the NotYetImplementedError" do
                file = __FILE__
                line_number = __LINE__ + 3
              
                error = extract_error do
                  @example = @example_group.it
                  @example.eval_block
                end
              
                error.pending_caller.should == "#{file}:#{line_number}"
              end
            end
          end
        end
      end

      describe "#backtrace" do        
        with_sandboxed_options do
          it "returns the backtrace from where the example was defined" do
            example_group = Class.new(ExampleGroup) do
              example "of something" do; end
            end
            
            example = example_group.examples.first
            example.backtrace.join("\n").should include("#{__FILE__}:#{__LINE__-4}")
          end
        end
      end
      
      describe "#implementation_backtrace (deprecated)" do
        with_sandboxed_options do
          before(:each) do
            Kernel.stub!(:warn)
          end

          it "sends a deprecation warning" do
            example_group = Class.new(ExampleGroup) {}
            example = example_group.example("") {}
            Kernel.should_receive(:warn).with(/#implementation_backtrace.*deprecated.*#backtrace instead/m)
            example.implementation_backtrace
          end
          
          it "returns the backtrace from where the example was defined" do
            example_group = Class.new(ExampleGroup) do
              example "of something" do; end
            end
            
            example = example_group.examples.first
            example.backtrace.join("\n").should include("#{__FILE__}:#{__LINE__-4}")
          end
        end
      end

      describe "#full_description" do
        it "should return the full description of the ExampleGroup and Example" do
          example_group = Class.new(ExampleGroup).describe("An ExampleGroup") do
            it "should do something" do
            end
          end
          example = example_group.examples.first
          example.full_description.should == "An ExampleGroup should do something"
        end
      end
      
      describe "#subject" do
        with_sandboxed_options do
          it "should return an instance variable named after the described type" do
            example_group = Class.new(ExampleGroup).describe(Array) do
              example {}
            end
            example = example_group.examples.first
            example.subject.should == []
          end
      
          it "should not barf on a module (as opposed to a class)" do
            example_group = Class.new(ExampleGroup).describe(ObjectSpace) do
              example {}
            end
            example_group.examples.first.subject.should be_nil
          end
      
          it "should not barf on a string" do
            example_group = Class.new(ExampleGroup).describe('foo') do
              example {}
            end
            example_group.examples.first.subject.should be_nil
          end
      
          it "should interact with the same scope as the before block" do
            example_group = Class.new(ExampleGroup) do
              subject { @foo = 'foo'}
              example { should == @foo}
              it { should == 'foo'}
            end
            example_group.run(options).should be_true
          end
        end
      end

      describe "#should" do
        with_sandboxed_options do
          class Thing
            def ==(other)
              true
            end
          end
          
          describe "in an ExampleGroup with the ivar defined in before" do
            attr_reader :example, :success

            before(:each) do
              example_group = describe(Thing, "1") do
                before(:each) { @spec_example_thing = 'expected' }
                it { should eql('expected') }
              end
              @example = example_group.examples.first
              @success = example_group.run(options)
            end

            it "should create an example using the description from the matcher" do
              example.description.should == 'should eql "expected"'
            end

            it "should test the matcher returned from the block" do
              success.should be_true
            end
          end

          describe "in an ExampleGroup with the subject defined using #subject" do
            it "should create an example using the description from the matcher" do
              example_group = describe(Thing, "2") do
                subject {'this is the subject'}
                it { should eql('this is the subject') }
              end
              example = example_group.examples.first
              example_group.run(options)
              example.description.should =~ /should eql "this is the subject"/
            end
          end
          
          describe "in an ExampleGroup using an implicit ivar" do
            it "should create an example using the description from the matcher" do
              example_group = describe(Thing, "3") do
                it { should == Thing.new }
              end
              example = example_group.examples.first
              success = example_group.run(options)
              example.description.should =~ /should == #<Spec::Example::Thing/
              success.should be_true
            end
          end
          
          after(:each) do
            ExampleGroup.reset
          end
          
        end
      end

      describe "#should_not" do
        with_sandboxed_options do

          attr_reader :example_group, :example, :success

          before do
            @example_group = Class.new(ExampleGroup) do
              def subject; @actual; end
              before(:each) { @actual = 'expected' }
              it { should_not eql('unexpected') }
            end
            @example = @example_group.examples.first

            @success = example_group.run(options)
          end

          it "should create an example using the description from the matcher" do
            example.description.should == 'should not eql "unexpected"'
          end

          it "should test the matcher returned from the block" do
            success.should be_true
          end

          after do
            ExampleGroup.reset
          end

        end
      end
    end

    describe "#options" do
      it "should expose the options hash" do
        example_group = Class.new(ExampleGroup)
        example = example_group.example "name", :this => 'that' do; end
        example.options[:this].should == 'that'
      end
    end

  end
end
