module Spec
  module Story
    module Runner
      class StoryRunner
        class << self
          attr_accessor :current_story_runner
          
          def scenario_from_current_story(scenario_name)
            current_story_runner.scenario_from_current_story(scenario_name)
          end
        end
        
        attr_accessor :stories, :scenarios, :current_story
        
        def initialize(scenario_runner, world_creator = World)
          StoryRunner.current_story_runner = self
          @scenario_runner = scenario_runner
          @world_creator = world_creator
          @stories = []
          @scenarios_by_story = {}
          @scenarios = []
          @listeners = []
        end
        
        def Story(title, narrative, params = {}, &body)
          story = Story.new(title, narrative, params, &body)
          @stories << story
          
          # collect scenarios
          collector = ScenarioCollector.new(story)
          story.run_in(collector)
          @scenarios += collector.scenarios
          @scenarios_by_story[story.title] = collector.scenarios
        end
        
        def run_stories
          return if @stories.empty?
          @listeners.each { |l| l.run_started(scenarios.size) }
          success = true
          @stories.each do |story|
            story.assign_steps_to(World)
            @current_story = story
            @listeners.each { |l| l.story_started(story.title, story.narrative) }
            scenarios = @scenarios_by_story[story.title]
            scenarios.each do |scenario|
              type = story[:type] || Object
              args = story[:args] || []
              world = @world_creator.create(type, *args)
              success = success & @scenario_runner.run(scenario, world)
            end
            @listeners.each { |l| l.story_ended(story.title, story.narrative) }
            World.step_mother.clear
          end
          unique_steps = (World.step_names.collect {|n| Regexp === n ? n.source : n.to_s}).uniq.sort
          @listeners.each { |l| l.collected_steps(unique_steps) }
          @listeners.each { |l| l.run_ended }
          return success
        end
        
        def add_listener(listener)
          @listeners << listener
        end
        
        def scenario_from_current_story(scenario_name)
          @scenarios_by_story[@current_story.title].find {|s| s.name == scenario_name }
        end
      end
    end
  end
end
