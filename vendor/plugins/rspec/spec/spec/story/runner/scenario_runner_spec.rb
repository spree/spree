require File.dirname(__FILE__) + '/../story_helper'

module Spec
  module Story
    module Runner
      describe ScenarioRunner do
        it 'should run a scenario in its story' do
          # given
          world = stub_everything
          scenario_runner = ScenarioRunner.new
          $answer = nil
          story = Story.new 'story', 'narrative' do
            @answer = 42 # this should be available to the scenario
          end
          scenario = Scenario.new story, 'scenario' do
            $answer = @answer
          end
          
          # when
          scenario_runner.run(scenario, world)
          
          # then
          $answer.should == 42
        end
        
        it 'should allow scenarios to share methods' do
          # given
          world = stub_everything
          $shared_invoked = 0
          story = Story.new 'story', 'narrative' do
            def shared
              $shared_invoked += 1
            end
          end
          scenario1 = Scenario.new story, 'scenario1' do
            shared()
          end
          scenario2 = Scenario.new story, 'scenario2' do
            shared()
          end
          scenario_runner = ScenarioRunner.new
          
          # when
          scenario_runner.run(scenario1, world)
          scenario_runner.run(scenario2, world)
          
          # then
          $shared_invoked.should == 2
        end
        
        it 'should notify listeners when a scenario starts' do
          # given
          world = stub_everything
          story = Story.new 'story', 'narrative' do end
          scenario = Scenario.new story, 'scenario1' do
            # succeeds
          end
          scenario_runner = ScenarioRunner.new
          mock_listener1 = stub_everything('listener1')
          mock_listener2 = stub_everything('listener2')
          scenario_runner.add_listener(mock_listener1)
          scenario_runner.add_listener(mock_listener2)
          
          # expect
          mock_listener1.should_receive(:scenario_started).with('story', 'scenario1')
          mock_listener2.should_receive(:scenario_started).with('story', 'scenario1')
          
          # when
          scenario_runner.run(scenario, world)
          
          # then
        end
        describe "when a scenario succeeds" do
          before(:each) do
            # given
            @world = stub_everything('world')
            @story = Story.new 'story', 'narrative' do end
            @scenario = Scenario.new @story, 'scenario1' do
              # succeeds
            end
            @scenario_runner = ScenarioRunner.new            
          end
          
          it 'should notify listeners' do
            #given
            mock_listener1 = stub_everything('listener1')
            mock_listener2 = stub_everything('listener2')
            @scenario_runner.add_listener(mock_listener1)
            @scenario_runner.add_listener(mock_listener2)
            
            # expect
            mock_listener1.should_receive(:scenario_succeeded).with('story', 'scenario1')
            mock_listener2.should_receive(:scenario_succeeded).with('story', 'scenario1')
            
            # when
            @scenario_runner.run(@scenario, @world)

            # then
          end
          
          it "should return true" do
            #when
            success = @scenario_runner.run(@scenario, @world)
            
            #then
            success.should == true
          end
        end

        describe "when a scenario raises an error (other than a pending error)" do
          before(:each) do
            # given
            @error = RuntimeError.new('oops')
            @story = Story.new 'title', 'narrative' do end
            @scenario = Scenario.new @story, 'scenario1' do
            end
            @scenario_runner = ScenarioRunner.new
            @world = stub_everything

            # expect
            @world.should_receive(:errors).twice.and_return([@error, @error])
          end
          
          it 'should notify listeners ONCE' do
            #given
            mock_listener = stub_everything('listener')
            @scenario_runner.add_listener(mock_listener)
            
            #expect
            mock_listener.should_receive(:scenario_failed).with('title', 'scenario1', @error).once

            # when
            @scenario_runner.run @scenario, @world

            # then
          end
          
          it "should return false" do
            # when
            success = @scenario_runner.run @scenario, @world

            # then
            success.should == false
          end
          
          
        end
        
        describe "when a scenario is pending" do
          before(:each) do
            # given
            @pending_error = Spec::Example::ExamplePendingError.new('todo')
            @story = Story.new 'title', 'narrative' do end
            @scenario = Scenario.new @story, 'scenario1' do
            end
            @scenario_runner = ScenarioRunner.new
            @world = stub_everything
            
            # expect
            @world.should_receive(:errors).twice.and_return([@pending_error, @pending_error])
          end
          
          it 'should notify listeners' do
            #given 
            mock_listener = mock('listener')
            @scenario_runner.add_listener(mock_listener)
            
            # expect
            mock_listener.should_receive(:scenario_started).with('title', 'scenario1')
            mock_listener.should_receive(:scenario_pending).with('title', 'scenario1', 'todo').once

            # when
            @scenario_runner.run @scenario, @world

            # then
          end
          
          it "should return true" do
            # when
            success = @scenario_runner.run @scenario, @world

            # then
            success.should == true
          end
        end

        describe "when a scenario has an empty body" do
          before(:each) do
            @story = Story.new 'title', 'narrative' do end
            @scenario = Scenario.new @story, 'scenario'
            @scenario_runner = ScenarioRunner.new
            @world = stub_everything
          end

          it "should mark the scenario as pending" do
            mock_listener = stub('listener', :scenario_started => true)
            @scenario_runner.add_listener mock_listener

            mock_listener.should_receive(:scenario_pending).with('title', 'scenario', '')
            @scenario_runner.run @scenario, @world
          end

          it "should return true" do
            # when
            success = @scenario_runner.run @scenario, @world

            # then
            success.should == true
          end
        end
      end
    end
  end
end
