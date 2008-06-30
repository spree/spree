require File.dirname(__FILE__) + '/../story_helper'

module Spec
  module Story
    module Runner
      
      describe StoryMediator do
        before(:each) do
          $story_mediator_spec_value = nil
          @step_group = StepGroup.new
          @step_group.create_matcher(:given, "given") { $story_mediator_spec_value = "given matched" }
          @step_group.create_matcher(:when, "when") { $story_mediator_spec_value = "when matched" }
          @step_group.create_matcher(:then, "then") { $story_mediator_spec_value = "then matched" }
          
          @scenario_runner = ScenarioRunner.new
          @runner = StoryRunner.new @scenario_runner
          @mediator = StoryMediator.new @step_group, @runner
        end
        
        def run_stories
          @mediator.run_stories
          @runner.run_stories
        end
        
        it "should have no stories" do
          @mediator.stories.should be_empty
        end
        
        it "should create two stories" do
          @mediator.create_story "story title", "story narrative"
          @mediator.create_story "story title 2", "story narrative 2"
          run_stories
          
          @runner.should have(2).stories
          @runner.stories.first.title.should == "story title"
          @runner.stories.first.narrative.should == "story narrative"
          @runner.stories.last.title.should == "story title 2"
          @runner.stories.last.narrative.should == "story narrative 2"
        end
        
        it "should create a scenario" do
          @mediator.create_story "title", "narrative"
          @mediator.create_scenario "scenario name"
          run_stories
          
          @runner.should have(1).scenarios
          @runner.scenarios.first.name.should == "scenario name"
          @runner.scenarios.first.story.should == @runner.stories.first
        end
        
        it "should create a given scenario step if one matches" do
          pending("need to untangle the dark mysteries of the story runner - something needs to get stubbed here") do
            story = @mediator.create_story "title", "narrative"
            @mediator.create_scenario "previous scenario"
            @mediator.create_scenario "current scenario"
            @mediator.create_given_scenario "previous scenario"
            run_stories
          
            $story_mediator_spec_value.should == "previous scenario matched"
          end
        end
                
        it "should create a given step if one matches" do
          @mediator.create_story "title", "narrative"
          @mediator.create_scenario "scenario"
          @mediator.create_given "given"
          run_stories
          
          $story_mediator_spec_value.should == "given matched"
        end
        
        it "should create a pending step if no given step matches" do
          @mediator.create_story "title", "narrative"
          @mediator.create_scenario "scenario"
          @mediator.create_given "no match"
          mock_listener = stub_everything("listener")
          mock_listener.should_receive(:scenario_pending).with("title", "scenario", "Unimplemented step: no match")
          @scenario_runner.add_listener mock_listener
          run_stories
        end
        
        it "should create a when step if one matches" do
          @mediator.create_story "title", "narrative"
          @mediator.create_scenario "scenario"
          @mediator.create_when "when"
          run_stories
          
          $story_mediator_spec_value.should == "when matched"
        end
        
        it "should create a pending step if no when step matches" do
          @mediator.create_story "title", "narrative"
          @mediator.create_scenario "scenario"
          @mediator.create_when "no match"
          mock_listener = stub_everything("listener")
          mock_listener.should_receive(:scenario_pending).with("title", "scenario", "Unimplemented step: no match")
          @scenario_runner.add_listener mock_listener
          run_stories
        end
        
        it "should create a then step if one matches" do
          @mediator.create_story "title", "narrative"
          @mediator.create_scenario "scenario"
          @mediator.create_then "then"
          run_stories
          
          $story_mediator_spec_value.should == "then matched"
        end
        
        it "should create a pending step if no 'then' step matches" do
          @mediator.create_story "title", "narrative"
          @mediator.create_scenario "scenario"
          @mediator.create_then "no match"
          mock_listener = stub_everything("listener")
          mock_listener.should_receive(:scenario_pending).with("title", "scenario", "Unimplemented step: no match")
          @scenario_runner.add_listener mock_listener
          run_stories
        end
        
        it "should pass options to the stories it creates" do
          @mediator = StoryMediator.new @step_group, @runner, :foo => :bar
          @mediator.create_story "story title", "story narrative"
        
          run_stories
          
          @runner.stories.first[:foo].should == :bar
        end
        
        it "should description" do
          @mediator = StoryMediator.new @step_group, @runner, :foo => :bar
          @mediator.create_story "title", "narrative"
          @mediator.create_scenario "scenario"
          @mediator.create_given "something"
          given = @mediator.last_step
          @mediator.add_to_last " else"
          given.name.should == "something else"
        end
        
      end
      
    end
  end
end