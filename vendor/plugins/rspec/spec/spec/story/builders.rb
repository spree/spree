module Spec
  module Story
    class StoryBuilder
      def initialize
        @title = 'a story'
        @narrative = 'narrative'
      end
      
      def title(value)
        @title = value
        self
      end
      
      def narrative(value)
        @narrative = value
        self
      end
      
      def to_story(&block)
        block = lambda {} unless block_given?
        Story.new @title, @narrative, &block
      end
    end
    
    class ScenarioBuilder
      def initialize
        @name = 'a scenario'
        @story = StoryBuilder.new.to_story
      end
      
      def name(value)
        @name = value
        self
      end
      
      def story(value)
        @story = value
        self
      end
      
      def to_scenario(&block)
        Scenario.new @story, @name, &block
      end
    end
  end
end
