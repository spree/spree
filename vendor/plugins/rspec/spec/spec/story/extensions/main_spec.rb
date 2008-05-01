require File.dirname(__FILE__) + '/../../../spec_helper'

module Spec
  module Story
    module Extensions
      describe "the main object extended with Main", :shared => true do
        before(:each) do
          @main = Class.new do; include Main; end
          @original_rspec_story_steps, $rspec_story_steps = $rspec_story_steps, nil
        end

        after(:each) do
          $rspec_story_steps = @original_rspec_story_steps
        end

        def have_step(type, name)
          return simple_matcher(%[step group containing a #{type} named #{name.inspect}]) do |actual|
            Spec::Story::Step === actual.find(type, name)
          end
        end
      end

      describe Main, "#run_story" do
        it_should_behave_like "the main object extended with Main"

        it "should create a PlainTextStoryRunner with run_story" do
          Spec::Story::Runner::PlainTextStoryRunner.should_receive(:new).and_return(mock("runner", :null_object => true))
          @main.run_story
        end

        it "should yield the runner if arity == 1" do
          File.should_receive(:read).with("some/path").and_return("Story: foo")
          $main_spec_runner = nil
          @main.run_story("some/path") do |runner|
            $main_spec_runner = runner
          end
          $main_spec_runner.should be_an_instance_of(Spec::Story::Runner::PlainTextStoryRunner)
        end

        it "should run in the runner if arity == 0" do
          File.should_receive(:read).with("some/path").and_return("Story: foo")
          $main_spec_runner = nil
          @main.run_story("some/path") do
            $main_spec_runner = self
          end
          $main_spec_runner.should be_an_instance_of(Spec::Story::Runner::PlainTextStoryRunner)
        end

        it "should tell the PlainTextStoryRunner to run with run_story" do
          runner = mock("runner")
          Spec::Story::Runner::PlainTextStoryRunner.should_receive(:new).and_return(runner)
          runner.should_receive(:run)
          @main.run_story
        end  
      end

      describe Main, "#steps_for" do
        it_should_behave_like "the main object extended with Main"

        it "should have no steps for a non existent key" do
          @main.steps_for(:key).find(:given, "foo").should be_nil
        end

        it "should create steps for a key" do
          $main_spec_invoked = false
          @main.steps_for(:key) do
            Given("foo") {
              $main_spec_invoked = true
            }
          end
          @main.steps_for(:key).find(:given, "foo").perform(Object.new, "foo")
          $main_spec_invoked.should be_true
        end

        it "should append steps to steps_for a given key" do
          @main.steps_for(:key) do
            Given("first") {}
          end
          @main.steps_for(:key) do
            Given("second") {}
          end
          @main.steps_for(:key).should have_step(:given, "first")
          @main.steps_for(:key).should have_step(:given, "second")
        end
      end

      describe Main, "#with_steps_for adding new steps" do
        it_should_behave_like "the main object extended with Main"

        it "should result in a group containing pre-existing steps and newly defined steps" do
          first_group = @main.steps_for(:key) do
            Given("first") {}
          end
          second_group = @main.with_steps_for(:key) do
            Given("second") {}
          end

          second_group.should have_step(:given, "first")
          second_group.should have_step(:given, "second")
        end

        it "should not add its steps to the existing group" do
          first_group = @main.steps_for(:key) do
            Given("first") {}
          end
          second_group = @main.with_steps_for(:key) do
            Given("second") {}
          end

          first_group.should have_step(:given, "first")
          first_group.should_not have_step(:given, "second")
        end
      end

      describe Main, "#with_steps_for running a story" do
        it_should_behave_like "the main object extended with Main"
        
        before(:each) do
          @runner = mock("runner")
          @runner_step_group = StepGroup.new
          @runner.stub!(:steps).and_return(@runner_step_group)
          @runner.stub!(:run)
          Spec::Story::Runner::PlainTextStoryRunner.stub!(:new).and_return(@runner)
        end
        
        it "should create a PlainTextStoryRunner with a path" do
          Spec::Story::Runner::PlainTextStoryRunner.should_receive(:new).with('path/to/file',{}).and_return(@runner)
          @main.with_steps_for(:foo) do
            run 'path/to/file'
          end
        end
        
        it "should create a PlainTextStoryRunner with a path and options" do
          Spec::Story::Runner::PlainTextStoryRunner.should_receive(:new).with(anything,{:bar => :baz}).and_return(@runner)
          @main.with_steps_for(:foo) do
            run 'path/to/file', :bar => :baz
          end
        end
        
        it "should pass the group it creates to the runner's steps" do
          steps = @main.steps_for(:ice_cream) do
            Given("vanilla") {}
          end
          @main.with_steps_for(:ice_cream) do
            run 'foo'
          end
          @runner_step_group.should have_step(:given, "vanilla")
        end
        
        it "should run a story" do
          @runner.should_receive(:run)
          Spec::Story::Runner::PlainTextStoryRunner.should_receive(:new).and_return(@runner)
          @main.with_steps_for(:foo) do
            run 'path/to/file'
          end
        end

      end
    end
  end
end