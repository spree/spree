require File.dirname(__FILE__) + '/../../spec_helper'

module Spec
  module Example
    describe 'ExampleGroupMethods' do
      it_should_behave_like "sandboxed rspec_options"
      attr_reader :example_group, :result, :reporter
      before(:each) do
        options.formatters << mock("formatter", :null_object => true)
        options.backtrace_tweaker = mock("backtrace_tweaker", :null_object => true)
        @reporter = FakeReporter.new(@options)
        options.reporter = reporter
        @example_group = Class.new(ExampleGroup) do
          describe("ExampleGroup")
          it "does nothing"
        end
        class << example_group
          public :include
        end
        @result = nil
      end

      after(:each) do
        ExampleGroup.reset
      end

      describe "#describe" do
        attr_reader :child_example_group
        before do
          @child_example_group = @example_group.describe("Another ExampleGroup") do
            it "should pass" do
              true.should be_true
            end
          end
        end

        it "should create a subclass of the ExampleGroup when passed a block" do
          child_example_group.superclass.should == @example_group
          @options.example_groups.should include(child_example_group)
        end

        it "should not inherit examples" do
          child_example_group.examples.length.should == 1
        end
      end

      describe "#it" do
        it "should should create an example instance" do
          lambda {
            @example_group.it("")
          }.should change { @example_group.examples.length }.by(1)
        end
      end

      describe "#xit" do
        before(:each) do
          Kernel.stub!(:warn)
        end

        it "should NOT  should create an example instance" do
          lambda {
            @example_group.xit("")
          }.should_not change(@example_group.examples, :length)
        end

        it "should warn that it is disabled" do
          Kernel.should_receive(:warn).with("Example disabled: foo")
          @example_group.xit("foo")
        end
      end

      describe "#examples" do
        it "should have Examples" do
          example_group = Class.new(ExampleGroup) do
            describe('example')
            it "should pass" do
              1.should == 1
            end
          end
          example_group.examples.length.should == 1
          example_group.examples.first.description.should == "should pass"
        end

        it "should not include methods that begin with test (only when TU interop is loaded)" do
          example_group = Class.new(ExampleGroup) do
            describe('example')
            def test_any_args(*args)
              true.should be_true
            end
            def test_something
              1.should == 1
            end
            def test
              raise "This is not a real test"
            end
            def testify
              raise "This is not a real test"
            end
          end
          example_group.examples.length.should == 0
          example_group.run.should be_true
        end

        it "should include methods that begin with should and has an arity of 0 in suite" do
          example_group = Class.new(ExampleGroup) do
            describe('example')
            def shouldCamelCase
              true.should be_true
            end
            def should_any_args(*args)
              true.should be_true
            end
            def should_something
              1.should == 1
            end
            def should_not_something
              1.should_not == 2
            end
            def should
              raise "This is not a real example"
            end
            def should_not
              raise "This is not a real example"
            end
          end
          example_group = example_group.dup
          example_group.examples.length.should == 4
          descriptions = example_group.examples.collect {|example| example.description}.sort
          descriptions.should include("shouldCamelCase")
          descriptions.should include("should_any_args")
          descriptions.should include("should_something")
          descriptions.should include("should_not_something")
        end

        it "should not include methods that begin with test_ and has an arity > 0 in suite" do
          example_group = Class.new(ExampleGroup) do
            describe('example')
            def test_invalid(foo)
              1.should == 1
            end
            def testInvalidCamelCase(foo)
              1.should == 1
            end
          end
          example_group.examples.length.should == 0
        end

        it "should not include methods that begin with should_ and has an arity > 0 in suite" do
          example_group = Class.new(ExampleGroup) do
            describe('example')
            def should_invalid(foo)
              1.should == 2
            end
            def shouldInvalidCamelCase(foo)
              1.should == 3
            end
            def should_not_invalid(foo)
              1.should == 4
            end
            def should_valid
              1.should == 1
            end
          end
          example_group.examples.length.should == 1
          example_group.run.should be_true
        end

        it "should run should_methods" do
          example_group = Class.new(ExampleGroup) do
            def should_valid
              1.should == 2
            end
          end
          example_group.examples.length.should == 1
          example_group.run.should be_false
        end
      end

      describe "#set_description" do
        attr_reader :example_group
        before do
          class << example_group
            public :set_description
          end
        end

        describe "#set_description(String)" do
          before(:each) do
            example_group.set_description("abc")
          end

          specify ".description should return the String passed into .set_description" do
            example_group.description.should == "abc"
          end

          specify ".described_type should provide nil as its type" do
            example_group.described_type.should be_nil
          end
        end

        describe "#set_description(Type)" do
          before(:each) do
            example_group.set_description(ExampleGroup)
          end

          specify ".description should return a String representation of that type (fully qualified) as its name" do
            example_group.description.should == "Spec::Example::ExampleGroup"
          end

          specify ".described_type should return the passed in type" do
            example_group.described_type.should == Spec::Example::ExampleGroup
          end
        end

        describe "#set_description(String, Type)" do
          before(:each) do
            example_group.set_description("behaving", ExampleGroup)
          end

          specify ".description should return String then space then Type" do
            example_group.description.should == "behaving Spec::Example::ExampleGroup"
          end

          specify ".described_type should return the passed in type" do
            example_group.described_type.should == Spec::Example::ExampleGroup
          end
        end

        describe "#set_description(Type, String not starting with a space)" do
          before(:each) do
            example_group.set_description(ExampleGroup, "behaving")
          end

          specify ".description should return the Type then space then String" do
            example_group.description.should == "Spec::Example::ExampleGroup behaving"
          end
        end

        describe "#set_description(Type, String starting with .)" do
          before(:each) do
            example_group.set_description(ExampleGroup, ".behaving")
          end

          specify ".description should return the Type then String" do
            example_group.description.should == "Spec::Example::ExampleGroup.behaving"
          end
        end

        describe "#set_description(Type, String containing .)" do
          before(:each) do
            example_group.set_description(ExampleGroup, "calling a.b")
          end

          specify ".description should return the Type then space then String" do
            example_group.description.should == "Spec::Example::ExampleGroup calling a.b"
          end
        end

        describe "#set_description(Type, String starting with .)" do
          before(:each) do
            example_group.set_description(ExampleGroup, ".behaving")
          end

          specify "should return the Type then String" do
            example_group.description.should == "Spec::Example::ExampleGroup.behaving"
          end
        end

        describe "#set_description(Type, String containing .)" do
          before(:each) do
            example_group.set_description(ExampleGroup, "is #1")
          end

          specify ".description should return the Type then space then String" do
            example_group.description.should == "Spec::Example::ExampleGroup is #1"
          end
        end

        describe "#set_description(String, Type, String)" do
          before(:each) do
            example_group.set_description("A", Hash, "with one entry")
          end

          specify ".description should return the first String then space then Type then second String" do
            example_group.description.should == "A Hash with one entry"
          end
        end

        describe "#set_description(Hash representing options)" do
          before(:each) do
            example_group.set_description(:a => "b", :spec_path => "blah")
          end

          it ".spec_path should expand the passed in :spec_path option passed into the constructor" do
            example_group.spec_path.should == File.expand_path("blah")
          end

          it ".description_options should return all the options passed in" do
            example_group.description_options.should == {:a => "b", :spec_path => "blah"}
          end

        end
      end

      describe "#description" do
        it "should return the same description instance for each call" do
          example_group.description.should eql(example_group.description)
        end

        it "should not add a space when description_text begins with #" do
          child_example_group = Class.new(example_group) do
            describe("#foobar", "Does something")
          end
          child_example_group.description.should == "ExampleGroup#foobar Does something"
        end

        it "should not add a space when description_text begins with ." do
          child_example_group = Class.new(example_group) do
            describe(".foobar", "Does something")
          end
          child_example_group.description.should == "ExampleGroup.foobar Does something"
        end
        
        it "should return the class name if nil" do
          example_group.set_description(nil)
          example_group.description.should =~ /Class:/
        end
        
        it "should return the class name if nil" do
          example_group.set_description("")
          example_group.description.should =~ /Class:/
        end
      end

      describe "#description_parts" do
        it "should return an Array of the current class description args" do
          example_group.description_parts.should == [example_group.description]
        end

        it "should return an Array of the description args from each class in the hierarchy" do
          child_example_group = Class.new(example_group)
          child_example_group.describe("Child", ExampleGroup)
          child_example_group.description.should_not be_empty

          grand_child_example_group = Class.new(child_example_group)
          grand_child_example_group.describe("GrandChild", ExampleGroup)
          grand_child_example_group.description.should_not be_empty

          grand_child_example_group.description_parts.should == [
            "ExampleGroup",
            "Child",
            Spec::Example::ExampleGroup,
            "GrandChild",
            Spec::Example::ExampleGroup
          ]
        end
      end

      describe "#described_type" do
        it "should return passed in type" do
          child_example_group = Class.new(example_group) do
            describe Object
          end
          child_example_group.described_type.should == Object
        end

        it "should return #described_type of superclass when no passed in type" do
          parent_example_group = Class.new(ExampleGroup) do
            describe Object, "#foobar"
          end
          child_example_group = Class.new(parent_example_group) do
            describe "not a type"
          end
          child_example_group.described_type.should == Object
        end
      end

      describe "#remove_after" do
        it "should unregister a given after(:each) block" do
          after_all_ran = false
          @example_group.it("example") {}
          proc = Proc.new { after_all_ran = true }
          ExampleGroup.after(:each, &proc)
          @example_group.run
          after_all_ran.should be_true

          after_all_ran = false
          ExampleGroup.remove_after(:each, &proc)
          @example_group.run
          after_all_ran.should be_false
        end
      end

      describe "#include" do
        it "should have accessible class methods from included module" do
          mod1_method_called = false
          mod1 = Module.new do
            class_methods = Module.new do
              define_method :mod1_method do
                mod1_method_called = true
              end
            end

            metaclass.class_eval do
              define_method(:included) do |receiver|
                receiver.extend class_methods
              end
            end
          end

          mod2_method_called = false
          mod2 = Module.new do
            class_methods = Module.new do
              define_method :mod2_method do
                mod2_method_called = true
              end
            end

            metaclass.class_eval do
              define_method(:included) do |receiver|
                receiver.extend class_methods
              end
            end
          end

          @example_group.include mod1, mod2

          @example_group.mod1_method
          @example_group.mod2_method
          mod1_method_called.should be_true
          mod2_method_called.should be_true
        end
      end

      describe "#number_of_examples" do
        it "should count number of specs" do
          proc do
            @example_group.it("one") {}
            @example_group.it("two") {}
            @example_group.it("three") {}
            @example_group.it("four") {}
          end.should change {@example_group.number_of_examples}.by(4)
        end
      end

      describe "#class_eval" do
        it "should allow constants to be defined" do
          example_group = Class.new(ExampleGroup) do
            describe('example')
            FOO = 1
            it "should reference FOO" do
              FOO.should == 1
            end
          end
          example_group.run
          Object.const_defined?(:FOO).should == false
        end
      end

      describe '#register' do
        it "should add ExampleGroup to set of ExampleGroups to be run" do
          options.example_groups.delete(example_group)
          options.example_groups.should_not include(example_group)
          
          example_group.register {}
          options.example_groups.should include(example_group)
        end
      end

      describe '#unregister' do
        before do
          options.example_groups.should include(example_group)
        end

        it "should remove ExampleGroup from set of ExampleGroups to be run" do
          example_group.unregister
          options.example_groups.should_not include(example_group)
        end
      end

      describe "#registration_backtrace" do
        it "returns the backtrace of where the ExampleGroup was registered" do
          example_group = Class.new(ExampleGroup)
          example_group.registration_backtrace.join("\n").should include("#{__FILE__}:#{__LINE__-1}")
        end
      end
    end
  end
end