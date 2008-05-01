require File.dirname(__FILE__) + '/../../spec_helper'

module Spec
  module Example
    describe ExampleGroup, "with :shared => true" do
      it_should_behave_like "sandboxed rspec_options"
      attr_reader :formatter, :example_group
      before(:each) do
        @formatter = Spec::Mocks::Mock.new("formatter", :null_object => true)
        options.formatters << formatter
        @example_group = Class.new(ExampleGroup).describe("example_group")
        class << example_group
          public :include
        end
      end

      after(:each) do
        @formatter.rspec_verify
        @example_group = nil
        $shared_example_groups.clear unless $shared_example_groups.nil?
      end

      def make_shared_example_group(name, opts=nil, &block)
        example_group = SharedExampleGroup.new(name, :shared => true, &block)
        SharedExampleGroup.add_shared_example_group(example_group)
        example_group
      end

      def non_shared_example_group()
        @non_shared_example_group ||= Class.new(ExampleGroup).describe("example_group")
      end

      it "should accept an optional options hash" do
        lambda { Class.new(ExampleGroup).describe("context") }.should_not raise_error(Exception)
        lambda { Class.new(ExampleGroup).describe("context", :shared => true) }.should_not raise_error(Exception)
      end

      it "should return all shared example_groups" do
        b1 = make_shared_example_group("b1", :shared => true) {}
        b2 = make_shared_example_group("b2", :shared => true) {}

        b1.should_not be(nil)
        b2.should_not be(nil)

        SharedExampleGroup.find_shared_example_group("b1").should equal(b1)
        SharedExampleGroup.find_shared_example_group("b2").should equal(b2)
      end

      it "should register as shared example_group" do
        example_group = make_shared_example_group("example_group") {}
        SharedExampleGroup.shared_example_groups.should include(example_group)
      end

      it "should not be shared when not configured as shared" do
        example_group = non_shared_example_group
        SharedExampleGroup.shared_example_groups.should_not include(example_group)
      end

      it "should complain when adding a second shared example_group with the same description" do
        describe "shared example_group", :shared => true do
        end
        lambda do
          describe "shared example_group", :shared => true do
          end
        end.should raise_error(ArgumentError)
      end

      it "should NOT complain when adding the same shared example_group instance again" do
        shared_example_group = Class.new(ExampleGroup).describe("shared example_group", :shared => true)
        SharedExampleGroup.add_shared_example_group(shared_example_group)
        SharedExampleGroup.add_shared_example_group(shared_example_group)
      end

      it "should NOT complain when adding the same shared example_group again (i.e. file gets reloaded)" do
        lambda do
          2.times do
            describe "shared example_group which gets loaded twice", :shared => true do
            end
          end
        end.should_not raise_error(ArgumentError)
      end

      it "should NOT complain when adding the same shared example_group in same file with different absolute path" do
        shared_example_group_1 = Class.new(ExampleGroup).describe(
          "shared example_group",
          :shared => true,
          :spec_path => "/my/spec/a/../shared.rb"
        )
        shared_example_group_2 = Class.new(ExampleGroup).describe(
          "shared example_group",
          :shared => true,
          :spec_path => "/my/spec/b/../shared.rb"
        )

        SharedExampleGroup.add_shared_example_group(shared_example_group_1)
        SharedExampleGroup.add_shared_example_group(shared_example_group_2)
      end

      it "should complain when adding a different shared example_group with the same name in a different file with the same basename" do
        shared_example_group_1 = Class.new(ExampleGroup).describe(
          "shared example_group",
          :shared => true,
          :spec_path => "/my/spec/a/shared.rb"
        )
        shared_example_group_2 = Class.new(ExampleGroup).describe(
          "shared example_group",
          :shared => true,
          :spec_path => "/my/spec/b/shared.rb"
        )

        SharedExampleGroup.add_shared_example_group(shared_example_group_1)
        lambda do
          SharedExampleGroup.add_shared_example_group(shared_example_group_2)
        end.should raise_error(ArgumentError, /already exists/)
      end

      it "should add examples to current example_group using it_should_behave_like" do
        shared_example_group = make_shared_example_group("shared example_group") do
          it("shared example") {}
          it("shared example 2") {}
        end

        example_group.it("example") {}
        example_group.number_of_examples.should == 1
        example_group.it_should_behave_like("shared example_group")
        example_group.number_of_examples.should == 3
      end

      it "should add examples to current example_group using include" do
        shared_example_group = describe "all things", :shared => true do
          it "should do stuff" do end
        end
        
        example_group = describe "one thing" do
          include shared_example_group
        end
        
        example_group.number_of_examples.should == 1
      end

      it "should add examples to current example_group using it_should_behave_like with a module" do
        AllThings = describe "all things", :shared => true do
          it "should do stuff" do end
        end
        
        example_group = describe "one thing" do
          it_should_behave_like AllThings
        end
        
        example_group.number_of_examples.should == 1
      end

      it "should run shared examples" do
        shared_example_ran = false
        shared_example_group = make_shared_example_group("shared example_group") do
          it("shared example") { shared_example_ran = true }
        end

        example_ran = false

        example_group.it_should_behave_like("shared example_group")
        example_group.it("example") {example_ran = true}
        example_group.run
        example_ran.should be_true
        shared_example_ran.should be_true
      end

      it "should run setup and teardown from shared example_group" do
        shared_setup_ran = false
        shared_teardown_ran = false
        shared_example_group = make_shared_example_group("shared example_group") do
          before { shared_setup_ran = true }
          after { shared_teardown_ran = true }
          it("shared example") { shared_example_ran = true }
        end

        example_ran = false

        example_group.it_should_behave_like("shared example_group")
        example_group.it("example") {example_ran = true}
        example_group.run
        example_ran.should be_true
        shared_setup_ran.should be_true
        shared_teardown_ran.should be_true
      end

      it "should run before(:all) and after(:all) only once from shared example_group" do
        shared_before_all_run_count = 0
        shared_after_all_run_count = 0
        shared_example_group = make_shared_example_group("shared example_group") do
          before(:all) { shared_before_all_run_count += 1}
          after(:all) { shared_after_all_run_count += 1}
          it("shared example") { shared_example_ran = true }
        end

        example_ran = false

        example_group.it_should_behave_like("shared example_group")
        example_group.it("example") {example_ran = true}
        example_group.run
        example_ran.should be_true
        shared_before_all_run_count.should == 1
        shared_after_all_run_count.should == 1
      end

      it "should include modules, included into shared example_group, into current example_group" do
        @formatter.should_receive(:add_example_group).with(any_args)

        shared_example_group = make_shared_example_group("shared example_group") do
          it("shared example") { shared_example_ran = true }
        end

        mod1_method_called = false
        mod1 = Module.new do
          define_method :mod1_method do
            mod1_method_called = true
          end
        end

        mod2_method_called = false
        mod2 = Module.new do
          define_method :mod2_method do
            mod2_method_called = true
          end
        end

        shared_example_group.include mod2

        example_group.it_should_behave_like("shared example_group")
        example_group.include mod1

        example_group.it("test") do
          mod1_method
          mod2_method
        end
        example_group.run
        mod1_method_called.should be_true
        mod2_method_called.should be_true
      end

      it "should make methods defined in the shared example_group available in consuming example_group" do
        shared_example_group = make_shared_example_group("shared example_group xyz") do
          def a_shared_helper_method
            "this got defined in a shared example_group"
          end
        end
        example_group.it_should_behave_like("shared example_group xyz")
        success = false
        example_group.it("should access a_shared_helper_method") do
          a_shared_helper_method
          success = true
        end
        example_group.run
        success.should be_true
      end

      it "should raise when named shared example_group can not be found" do
        lambda {
          example_group.it_should_behave_like("non-existent shared example group")
          violated
        }.should raise_error("Shared Example Group 'non-existent shared example group' can not be found")
      end
    end
  end
end
