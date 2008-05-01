require File.dirname(__FILE__) + '/../story_helper'

module Spec
  module Story
    module Runner
      describe ScenarioCollector do
        it 'should construct scenarios with the supplied story' do
          # given
          story = stub_everything('story')
          scenario_collector = ScenarioCollector.new(story)
          
          # when
          scenario_collector.Scenario 'scenario1' do end
          scenario_collector.Scenario 'scenario2' do end
          scenarios = scenario_collector.scenarios
          
          # then
          scenario_collector.should have(2).scenarios
          scenarios.first.name.should == 'scenario1'
          scenarios.first.story.should equal(story)
          scenarios.last.name.should == 'scenario2'
          scenarios.last.story.should equal(story)
        end
      end
    end
  end
end
