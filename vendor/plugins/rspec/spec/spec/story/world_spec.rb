require File.dirname(__FILE__) + '/story_helper'

require 'spec/story'

module Spec
  module Story
    describe World do
      before :each do
        World.listeners.clear
      end

      after :each do
        World.listeners.clear
        World.step_mother.clear
      end

      it 'should create an object that mixes in a World' do
        # when
        obj = World::create

        # then
        obj.should be_kind_of(World)
      end

      it 'should create a World from any object type' do
        # when
        obj = World::create String

        # then
        obj.should be_kind_of(String)
        obj.should be_kind_of(World)
      end

      it 'should pass arguments to #new when creating an object of a specified type that mixes in a world' do
        # given
        Thing = Struct.new(:name, :age)

        # when
        obj = World::create Thing, "David", "I'm not telling"

        # then
        obj.should be_an_instance_of(Thing)
        obj.name.should == "David"
        obj.age.should == "I'm not telling"
        obj.should be_kind_of(World)
      end

      def ensure_world_executes_step(&block)
        # given
        obj = World::create
        $step_ran = false

        # when
        obj.instance_eval(&block)

        # then
        $step_ran.should be_true
      end

      it 'should execute a Given, When or Then step' do
        ensure_world_executes_step do
          Given 'a given' do
            $step_ran = true
          end
        end

        ensure_world_executes_step do
          When 'an event' do
            $step_ran = true
          end
        end

        ensure_world_executes_step do
          Then 'an outcome' do
            $step_ran = true
          end
        end
      end

      it 'should interpret Given... And... as multiple givens' do
        # given
        world = World.create
        $steps = []

        # when
        world.instance_eval do
          Given 'step 1' do
            $steps << 1
          end
          And 'step 2' do
            $steps << 2
          end
        end

        # then
        $steps.should == [1,2]
        World.step_mother.find(:given, 'step 1').should_not be_nil
        World.step_mother.find(:given, 'step 2').should_not be_nil
      end

      it 'should interpret When... And... as multiple events' do
        # given
        world = World.create
        $steps = []

        # when
        world.instance_eval do
          When 'step 1' do
            $steps << 1
          end
          And 'step 2' do
            $steps << 2
          end
        end

        # then
        $steps.should == [1,2]
        World.step_mother.find(:when, 'step 1').should_not be_nil
        World.step_mother.find(:when, 'step 2').should_not be_nil
      end

      it 'should interpret Then... And... as multiple outcomes' do
        # given
        world = World.create
        $steps = []

        # when
        world.instance_eval do
          Then 'step 1' do
            $steps << 1
          end
          And 'step 2' do
            $steps << 2
          end
        end

        # then
        $steps.should == [1,2]
        World.step_mother.find(:then, 'step 1').should_not be_nil
        World.step_mother.find(:then, 'step 2').should_not be_nil
      end

      it 'should reuse a given across scenarios' do
        # given
        $num_invoked = 0
        a_world = World::create
        a_world.instance_eval do
          Given 'a given' do
            $num_invoked += 1
          end
        end
        another_world = World::create

        # when
        another_world.instance_eval do
          Given 'a given' # without a body
        end

        # then
        $num_invoked.should == 2
      end

      it 'should reuse an event across scenarios' do
        # given
        $num_invoked = 0
        a_world = World::create
        a_world.instance_eval do
          When 'an event' do
            $num_invoked += 1
          end
        end

        another_world = World::create

        # when
        another_world.instance_eval do
          When 'an event' # without a body
        end

        # then
        $num_invoked.should == 2
      end

      it 'should reuse an outcome across scenarios' do
        # given
        $num_invoked = 0
        a_world = World::create
        a_world.instance_eval do
          Then 'an outcome' do
            $num_invoked += 1
          end
        end

        another_world = World::create

        # when
        another_world.instance_eval do
          Then 'an outcome' # without a body
        end

        # then
        $num_invoked.should == 2
      end

      it 'should preserve instance variables between steps within a scenario' do
        # given
        world = World::create
        $first = nil
        $second = nil

        # when
        world.instance_eval do
          Given 'given' do
            @first = 'first'
          end
          When 'event' do
            @second = @first # from given
          end
          Then 'outcome' do
            $first = @first # from given
            $second = @second # from event
          end
        end

        # then
        $first.should == 'first'
        $second.should == 'first'
      end

      it 'should invoke a reused step in the new object instance' do
        # given
        $instances = []
        $debug = true
        world1 = World.create
        world1.instance_eval do
          Given 'a given' do
            $instances << self.__id__
          end
        end
        world2 = World.create

        # when
        world2.instance_eval do
          Given 'a given' # reused
          Then 'an outcome' do
            $instances << __id__
          end
        end
        $debug = false
        # then
        $instances.should == [ world1.__id__, world2.__id__, world2.__id__ ]
      end

      def ensure_world_collects_error(expected_error, &block)
        # given
        world = World.create
        # $error = nil

        # when
        world.start_collecting_errors
        world.instance_eval(&block)

        # then
        world.should have(1).errors
        world.errors[0].should be_kind_of(expected_error)
      end

      it 'should collect a failure from a Given step' do
        ensure_world_collects_error RuntimeError do
          Given 'a given' do
            raise RuntimeError, "oops"
          end
        end
      end

      it 'should collect a failure from a When step' do
        ensure_world_collects_error RuntimeError do
          When 'an event' do
            raise RuntimeError, "oops"
          end
        end
      end

      it 'should collect a failure from a Then step' do
        ensure_world_collects_error RuntimeError do
          Then 'an outcome' do
            raise RuntimeError, "oops"
          end
        end
      end

      it 'should inform listeners when it runs a Given, When or Then step' do
        # given
        world = World.create
        mock_listener1 = mock('listener1')
        mock_listener2 = mock('listener2')
        World.add_listener(mock_listener1)
        World.add_listener(mock_listener2)

        # expect
        mock_listener1.should_receive(:step_upcoming).with(:given, 'a context')
        mock_listener1.should_receive(:step_succeeded).with(:given, 'a context')
        mock_listener1.should_receive(:step_upcoming).with(:when, 'an event')
        mock_listener1.should_receive(:step_succeeded).with(:when, 'an event')
        mock_listener1.should_receive(:step_upcoming).with(:then, 'an outcome')
        mock_listener1.should_receive(:step_succeeded).with(:then, 'an outcome')

        mock_listener2.should_receive(:step_upcoming).with(:given, 'a context')
        mock_listener2.should_receive(:step_succeeded).with(:given, 'a context')
        mock_listener2.should_receive(:step_upcoming).with(:when, 'an event')
        mock_listener2.should_receive(:step_succeeded).with(:when, 'an event')
        mock_listener2.should_receive(:step_upcoming).with(:then, 'an outcome')
        mock_listener2.should_receive(:step_succeeded).with(:then, 'an outcome')

        # when
        world.instance_eval do
          Given 'a context' do end
          When 'an event' do end
          Then 'an outcome' do end
        end

        # then
      end

      it 'should tell listeners but not execute the step in dry-run mode' do
        # given
        World.stub!(:dry_run).and_return(true)
        mock_listener = mock('listener')
        World.add_listener(mock_listener)
        $step_invoked = false
        world = World.create

        # expect
        mock_listener.should_receive(:step_upcoming).with(:given, 'a context')
        mock_listener.should_receive(:step_succeeded).with(:given, 'a context')

        # when
        world.instance_eval do
          Given 'a context' do
            $step_invoked = true
          end
        end

        # then
        $step_invoked.should be(false)
      end

      it 'should suppress listeners while it runs a GivenScenario' do
        # given
        $scenario_ran = false

        scenario = ScenarioBuilder.new.name('a scenario').to_scenario do
          $scenario_ran = true
          Given 'given' do end
          When 'event' do end
          Then 'outcome' do end
        end

        given_scenario = GivenScenario.new('a scenario')
        Runner::StoryRunner.should_receive(:scenario_from_current_story).
          with('a scenario').and_return(scenario)

        world = World.create
        listener = mock('listener')
        World.add_listener(listener)

        # expect
        listener.should_receive(:found_scenario).with(:'given scenario', 'a scenario')
        listener.should_receive(:step_succeeded).never.with(:given, 'given')
        listener.should_receive(:step_succeeded).never.with(:when, 'event')
        listener.should_receive(:step_succeeded).never.with(:then, 'outcome')

        # when
        world.GivenScenario 'a scenario'

        # then
        $scenario_ran.should be_true
      end

      it 'should interpret GivenScenario... And... as multiple givens' do
        # given
        world = World.create
        $steps = []

        scenario = ScenarioBuilder.new.name('a scenario').to_scenario do
          $steps << 1
        end
        Runner::StoryRunner.should_receive(:scenario_from_current_story).
          with('a scenario').and_return(scenario)

        # when
        world.instance_eval do
          GivenScenario 'a scenario'
          And 'step 2' do
            $steps << 2
          end
        end

        # then
        $steps.should == [1,2]
        World.step_mother.find(:given, 'step 2').should_not be_nil
      end

      it 'should provide rspec matchers' do
        # given
        world = World.create

        # then
        world.instance_eval do
          'hello'.should match(/^hello$/)
        end
      end

      it "should use assigned matchers" do
        world = World.create

        World.should_receive(:use).with(steps = Object.new)

        World.use(steps)
      end
    end
  end
end
