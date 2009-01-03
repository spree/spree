require File.dirname(__FILE__) + '/../../spec_helper'

module Spec
  module Example
    describe ExampleGroup, "with :shared => true" do
      with_sandboxed_options do
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
          Spec::Example::SharedExampleGroup.clear
        end
        
        describe "#register" do
          it "creates a new shared example group with the submitted args" do
            block = lambda {}
            group = SharedExampleGroup.new("shared group") do end
            Spec::Example::SharedExampleGroup.should_receive(:new).with("share me", &block).and_return(group)
            Spec::Example::SharedExampleGroup.register("share me", &block)
          end

          it "registers the shared example group" do
            lambda do
              Spec::Example::SharedExampleGroup.register "share me" do end
            end.should change {Spec::Example::SharedExampleGroup.count}.by(1)
          end
        end

        it "complains when adding a second shared example_group with the same description" do
          describe "shared example_group", :shared => true do
          end
          lambda do
            describe "shared example_group", :shared => true do
            end
          end.should raise_error(ArgumentError)
        end
        
        it "does NOT add the same group twice" do
          lambda do
            2.times do
              describe "shared example_group which gets loaded twice", :shared => true do
              end
            end
          end.should change {Spec::Example::SharedExampleGroup.count}.by(1)
        end

        it "does NOT complain when adding the same shared example_group again (i.e. file gets reloaded)" do
          lambda do
            2.times do
              describe "shared example_group which gets loaded twice", :shared => true do
              end
            end
          end.should_not raise_error(ArgumentError)
        end

        it "does NOT complain when adding the same shared example_group in same file with different absolute path" do
          SharedExampleGroup.register(
            "shared example_group",
            :shared => true,
            :spec_path => "/my/spec/a/../shared.rb"
          )
          SharedExampleGroup.register(
            "shared example_group",
            :shared => true,
            :spec_path => "/my/spec/b/../shared.rb"
          )
        end

        it "complains when adding a different shared example_group with the same name in a different file with the same basename" do
          SharedExampleGroup.register(
            "shared example_group",
            :shared => true,
            :spec_path => "/my/spec/a/shared.rb"
          )
          lambda do
            SharedExampleGroup.register(
              "shared example_group",
              :shared => true,
              :spec_path => "/my/spec/b/shared.rb"
            )
          end.should raise_error(ArgumentError, /already exists/)
        end

        it "adds examples to current example_group using it_should_behave_like" do
          shared_example_group = SharedExampleGroup.register("shared example_group") do
            it("shared example") {}
            it("shared example 2") {}
          end

          example_group.it("example") {}
          example_group.number_of_examples.should == 1
          example_group.it_should_behave_like("shared example_group")
          example_group.number_of_examples.should == 3
        end

        it "adds examples to from two shared groups" do
          shared_example_group_1 = SharedExampleGroup.register("shared example_group 1") do
            it("shared example 1") {}
          end

          shared_example_group_1 = SharedExampleGroup.register("shared example_group 2") do
            it("shared example 2") {}
          end

          example_group.it("example") {}
          example_group.number_of_examples.should == 1
          example_group.it_should_behave_like("shared example_group 1", "shared example_group 2")
          example_group.number_of_examples.should == 3
        end

        it "adds examples to current example_group using include" do
          shared_example_group = describe "all things", :shared => true do
            it "should do stuff" do end
          end
        
          example_group = describe "one thing" do
            include shared_example_group
          end
        
          example_group.number_of_examples.should == 1
        end

        it "adds examples to current example_group using it_should_behave_like with a module" do
          AllThings = describe "all things", :shared => true do
            it "should do stuff" do end
          end
        
          example_group = describe "one thing" do
            it_should_behave_like AllThings
          end
        
          example_group.number_of_examples.should == 1
        end

        it "runs shared examples" do
          shared_example_ran = false
          shared_example_group = SharedExampleGroup.register("shared example_group") do
            it("shared example") { shared_example_ran = true }
          end

          example_ran = false

          example_group.it_should_behave_like("shared example_group")
          example_group.it("example") {example_ran = true}
          example_group.run(options)
          example_ran.should be_true
          shared_example_ran.should be_true
        end

        it "runs before(:each) and after(:each) from shared example_group" do
          shared_setup_ran = false
          shared_teardown_ran = false
          shared_example_group = SharedExampleGroup.register("shared example_group") do
            before(:each) { shared_setup_ran = true }
            after(:each)  { shared_teardown_ran = true }
            it("shared example") { shared_example_ran = true }
          end

          example_ran = false

          example_group.it_should_behave_like("shared example_group")
          example_group.it("example") {example_ran = true}
          example_group.run(options)
          example_ran.should be_true
          shared_setup_ran.should be_true
          shared_teardown_ran.should be_true
        end

        it "should run before(:all) and after(:all) only once from shared example_group" do
          shared_before_all_run_count = 0
          shared_after_all_run_count = 0
          shared_example_group = SharedExampleGroup.register("shared example_group") do
            before(:all) { shared_before_all_run_count += 1}
            after(:all)  { shared_after_all_run_count += 1}
            it("shared example") { shared_example_ran = true }
          end

          example_ran = false

          example_group.it_should_behave_like("shared example_group")
          example_group.it("example") {example_ran = true}
          example_group.run(options)
          example_ran.should be_true
          shared_before_all_run_count.should == 1
          shared_after_all_run_count.should == 1
        end

        it "should include modules, included into shared example_group, into current example_group" do
          @formatter.should_receive(:add_example_group).with(any_args)

          shared_example_group = SharedExampleGroup.register("shared example_group") do
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

          shared_example_group.__send__ :include, mod2

          example_group.it_should_behave_like("shared example_group")
          example_group.include mod1

          example_group.it("test") do
            mod1_method
            mod2_method
          end
          example_group.run(options)
          mod1_method_called.should be_true
          mod2_method_called.should be_true
        end

        it "should make methods defined in the shared example_group available in consuming example_group" do
          shared_example_group = SharedExampleGroup.register("shared example_group xyz") do
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
          example_group.run(options)
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
end
