require File.dirname(__FILE__) + '/../story_helper'

module Spec
  module Story
    module Runner
      describe StoryRunner do
        it 'should collect all the stories' do
          # given
          story_runner = StoryRunner.new(stub('scenario_runner'))
          
          # when
          story_runner.Story 'title1', 'narrative1' do end
          story_runner.Story 'title2', 'narrative2' do end
          stories = story_runner.stories
          
          # then
          story_runner.should have(2).stories
          stories.first.title.should == 'title1'
          stories.first.narrative.should == 'narrative1'
          stories.last.title.should == 'title2'
          stories.last.narrative.should == 'narrative2'
        end
        
        it 'should gather all the scenarios in the stories' do
          # given
          story_runner = StoryRunner.new(stub('scenario_runner'))
          
          # when
          story_runner.Story "story1", "narrative1" do
            Scenario "scenario1" do end
            Scenario "scenario2" do end
          end
          story_runner.Story "story2", "narrative2" do
            Scenario "scenario3" do end
          end
          scenarios = story_runner.scenarios
          
          # then
          story_runner.should have(3).scenarios
          scenarios[0].name.should == 'scenario1'
          scenarios[1].name.should == 'scenario2'
          scenarios[2].name.should == 'scenario3'
        end
        
        # captures worlds passed into a ScenarioRunner
        class ScenarioWorldCatcher
          attr_accessor :worlds
          def run(scenario, world)
           (@worlds ||= [])  << world
          end
        end
        
        it 'should run each scenario in a separate object' do
          # given
          scenario_world_catcher = ScenarioWorldCatcher.new
          story_runner = StoryRunner.new(scenario_world_catcher)
          story_runner.Story 'story', 'narrative' do
            Scenario 'scenario1' do end
            Scenario 'scenario2' do end
          end
          
          # when
          story_runner.run_stories
          
          # then
          worlds = scenario_world_catcher.worlds
          scenario_world_catcher.should have(2).worlds
          worlds[0].should_not == worlds[1]
        end
        
        it "should return false if the scenario runner returns false ever" do
          #given
          stub_scenario_runner = stub_everything
          story_runner = StoryRunner.new(stub_scenario_runner)
          story_runner.Story 'story', 'narrative' do
            Scenario 'scenario1' do end
            Scenario 'scenario2' do end
          end
          
          # expect
          stub_scenario_runner.should_receive(:run).once.and_return(false,true)
          
          # when
          success = story_runner.run_stories
          
          #then
          success.should == false
        end
        
        it "should return true if the scenario runner returns true for all scenarios" do
          #given
          stub_scenario_runner = stub_everything
          story_runner = StoryRunner.new(stub_scenario_runner)
          story_runner.Story 'story', 'narrative' do
            Scenario 'scenario1' do end
            Scenario 'scenario2' do end
          end
          
          # expect
          stub_scenario_runner.should_receive(:run).once.and_return(true,true)
          
          # when
          success = story_runner.run_stories
          
          #then
          success.should == true
        end
        
        it 'should use the provided world creator to create worlds' do
          # given
          stub_scenario_runner = stub_everything
          mock_world_creator = mock('world creator')
          story_runner = StoryRunner.new(stub_scenario_runner, mock_world_creator)
          story_runner.Story 'story', 'narrative' do
            Scenario 'scenario1' do end
            Scenario 'scenario2' do end
          end
          
          # expect
          mock_world_creator.should_receive(:create).twice
          
          # when
          story_runner.run_stories
          
          # then
        end
        
        it 'should notify listeners of the scenario count when the run starts' do
          # given
          story_runner = StoryRunner.new(stub_everything)
          mock_listener1 = stub_everything('listener1')
          mock_listener2 = stub_everything('listener2')
          story_runner.add_listener(mock_listener1)
          story_runner.add_listener(mock_listener2)
          
          story_runner.Story 'story1', 'narrative1' do
            Scenario 'scenario1' do end
          end
          story_runner.Story 'story2', 'narrative2' do
            Scenario 'scenario2' do end
            Scenario 'scenario3' do end
          end
          
          # expect
          mock_listener1.should_receive(:run_started).with(3)
          mock_listener2.should_receive(:run_started).with(3)
          
          # when
          story_runner.run_stories
          
          # then
        end
        
        it 'should notify listeners when a story starts' do
          # given
          story_runner = StoryRunner.new(stub_everything)
          mock_listener1 = stub_everything('listener1')
          mock_listener2 = stub_everything('listener2')
          story_runner.add_listener(mock_listener1)
          story_runner.add_listener(mock_listener2)
          
          story_runner.Story 'story1', 'narrative1' do
            Scenario 'scenario1' do end
          end
          story_runner.Story 'story2', 'narrative2' do
            Scenario 'scenario2' do end
            Scenario 'scenario3' do end
          end
          
          # expect
          mock_listener1.should_receive(:story_started).with('story1', 'narrative1')
          mock_listener1.should_receive(:story_ended).with('story1', 'narrative1')
          mock_listener2.should_receive(:story_started).with('story2', 'narrative2')
          mock_listener2.should_receive(:story_ended).with('story2', 'narrative2')
          
          # when
          story_runner.run_stories
          
          # then
        end
        
        it 'should notify listeners when the run ends' do
          # given
          story_runner = StoryRunner.new(stub_everything)
          mock_listener1 = stub_everything('listener1')
          mock_listener2 = stub_everything('listener2')
          story_runner.add_listener mock_listener1
          story_runner.add_listener mock_listener2
          story_runner.Story 'story1', 'narrative1' do
            Scenario 'scenario1' do end
          end
          
          # expect
          mock_listener1.should_receive(:run_ended)
          mock_listener2.should_receive(:run_ended)
          
          # when
          story_runner.run_stories
          
          # then
        end
        
        it 'should run a story in an instance of a specified class' do
          # given
          scenario_world_catcher = ScenarioWorldCatcher.new
          story_runner = StoryRunner.new(scenario_world_catcher)
          story_runner.Story 'title', 'narrative', :type => String do
            Scenario 'scenario' do end
          end
          
          # when
          story_runner.run_stories
          
          # then
          scenario_world_catcher.worlds[0].should be_kind_of(String)
          scenario_world_catcher.worlds[0].should be_kind_of(World)
        end
        
        it 'should pass initialization params through to the constructed instance' do
          # given
          scenario_world_catcher = ScenarioWorldCatcher.new
          story_runner = StoryRunner.new(scenario_world_catcher)
          story_runner.Story 'title', 'narrative', :type => Array, :args => [3]  do
            Scenario 'scenario' do end
          end
          
          # when
          story_runner.run_stories
          
          # then
          scenario_world_catcher.worlds[0].should be_kind_of(Array)
          scenario_world_catcher.worlds[0].size.should == 3
        end
        
        it 'should find a scenario in the current story by name' do
          # given
          story_runner = StoryRunner.new(ScenarioRunner.new)
          $scenario = nil
          
          story_runner.Story 'title', 'narrative' do
            Scenario 'first scenario' do
            end
            Scenario 'second scenario' do
              $scenario = StoryRunner.scenario_from_current_story 'first scenario'
            end
          end
          
          # when
          story_runner.run_stories
          
          # then
          $scenario.name.should == 'first scenario'
        end
        
        it "should clean the steps between stories" do
          #given
          story_runner = StoryRunner.new(ScenarioRunner.new)
          result = mock 'result'
          
          step1 = Step.new('step') do
            result.one
          end
          steps1 = StepGroup.new
          steps1.add :when, step1
          
          story_runner.Story 'title', 'narrative', :steps_for => steps1 do
            Scenario 'first scenario' do
              When 'step'
            end
          end
          
          step2 = Step.new('step') do
            result.two
          end
          steps2 = StepGroup.new
          steps2.add :when, step2
          
          story_runner.Story 'title2', 'narrative', :steps_for => steps2 do
            Scenario 'second scenario' do
              When 'step'
            end
          end
          
          #then
          result.should_receive(:one)
          result.should_receive(:two)
          
          #when
          story_runner.run_stories
        end
      end
    end
  end
end
