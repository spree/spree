require File.dirname(__FILE__) + '/story_helper'

module Spec
  module Story
    describe StepGroup do
      before(:each) do
        @step_group = StepGroup.new
      end
      
      it "should not find a matcher if empty" do
        @step_group.find(:given, "this and that").should be_nil
      end
      
      it "should create a given_scenario matcher" do
        step = @step_group.given_scenario("this and that") {}
        @step_group.find(:given_scenario, "this and that").should_not be_nil
        @step_group.find(:given_scenario, "this and that").should equal(step)
      end
      
      it "should create a given matcher" do
        step = @step_group.given("this and that") {}
        @step_group.find(:given, "this and that").should equal(step)
      end
      
      it "should create a when matcher" do
        step = @step_group.when("this and that") {}
        @step_group.find(:when, "this and that").should equal(step)
      end
      
      it "should create a them matcher" do
        step = @step_group.then("this and that") {}
        @step_group.find(:then, "this and that").should equal(step)
      end
      
      it "should add a matcher object" do
        step = Step.new("this and that") {}
        @step_group.add(:given, step)
        @step_group.find(:given, "this and that").should equal(step)
      end
      
      it "should add it matchers to another StepGroup (with one given)" do
        source = StepGroup.new
        target = StepGroup.new
        step = source.given("this and that") {}
        source.add_to target
        target.find(:given, "this and that").should equal(step)
      end
      
      it "should add it matchers to another StepGroup (with some of each type)" do
        source = StepGroup.new
        target = StepGroup.new
        given_scenario = source.given_scenario("1") {}
        given = source.given("1") {}
        when1 = source.when("1") {}
        when2 = source.when("2") {}
        then1 = source.then("1") {}
        then2 = source.then("2") {}
        then3 = source.then("3") {}
        source.add_to target
        target.find(:given_scenario, "1").should equal(given_scenario)
        target.find(:given, "1").should equal(given)
        target.find(:when, "1").should equal(when1)
        target.find(:when, "2").should equal(when2)
        target.find(:then, "1").should equal(then1)
        target.find(:then, "2").should equal(then2)
        target.find(:then, "3").should equal(then3)
      end
      
      it "should append another collection" do
        matchers_to_append = StepGroup.new
        step = matchers_to_append.given("this and that") {}
        @step_group << matchers_to_append
        @step_group.find(:given, "this and that").should equal(step)
      end
      
      it "should append several other collections" do
        matchers_to_append = StepGroup.new
        more_matchers_to_append = StepGroup.new
        first_matcher = matchers_to_append.given("this and that") {}
        second_matcher = more_matchers_to_append.given("and the other") {}
        @step_group << matchers_to_append
        @step_group << more_matchers_to_append
        @step_group.find(:given, "this and that").should equal(first_matcher)
        @step_group.find(:given, "and the other").should equal(second_matcher)
      end
      
      it "should yield itself on initialization" do
        begin
          $step_group_spec_step = nil
          matchers = StepGroup.new do |matchers|
            $step_group_spec_step = matchers.given("foo") {}
          end
          $step_group_spec_step.matches?("foo").should be_true
        ensure
          $step_group_spec_step = nil
        end
      end
      
      it "should support defaults" do
        class StepGroupSubclass < StepGroup
          steps do |add|
            add.given("foo") {}
          end
        end
        StepGroupSubclass.new.find(:given, "foo").should_not be_nil
      end
      
      it "should create a Given" do
        sub = Class.new(StepGroup).new
        step = sub.Given("foo") {}
        sub.find(:given, "foo").should == step
      end
      
      it "should create a When" do
        sub = Class.new(StepGroup).new
        step = sub.When("foo") {}
        sub.find(:when, "foo").should == step
      end
      
      it "should create a Then" do
        sub = Class.new(StepGroup).new
        step = sub.Then("foo") {}
        sub.find(:then, "foo").should == step
      end
      
      it "should create steps in a block" do
        sub = Class.new(StepGroup).new do
          Given("a given") {}
          When("a when") {}
          Then("a then") {}
        end
        sub.find(:given, "a given").should_not be_nil
        sub.find(:when, "a when").should_not be_nil
        sub.find(:then, "a then").should_not be_nil
      end
      
      it "should clear itself" do
        step = @step_group.given("this and that") {}
        @step_group.clear
        @step_group.find(:given, "this and that").should be_nil
      end
      
      it "should tell you when it is empty" do
        @step_group.should be_empty
      end
      
      it "should tell you when it is not empty" do
        @step_group.given("this and that") {}
        @step_group.should_not be_empty
      end
      
      it "should handle << nil" do
        @step_group << nil
      end
    end
  end
end
