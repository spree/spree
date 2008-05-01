module Spec
  module Story
    module Runner
      class ScenarioCollector
        attr_accessor :scenarios
        
        def initialize(story)
          @story = story
          @scenarios = []
        end
        
        def Scenario(name, &body)
          @scenarios << Scenario.new(@story, name, &body)
        end
      end
    end
  end
end
