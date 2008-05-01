module Spec
  module Story
    module Runner
      class ScenarioRunner
        def initialize
          @listeners = []
        end
        
        def run(scenario, world)
          @listeners.each { |l| l.scenario_started(scenario.story.title, scenario.name) }
          run_story_ignoring_scenarios(scenario.story, world)
          
          world.start_collecting_errors
          world.instance_eval(&scenario.body)
          if world.errors.empty?
            @listeners.each { |l| l.scenario_succeeded(scenario.story.title, scenario.name) }
          else
            if Spec::Example::ExamplePendingError === (e = world.errors.first)
              @listeners.each { |l| l.scenario_pending(scenario.story.title, scenario.name, e.message) }
            else
              @listeners.each { |l| l.scenario_failed(scenario.story.title, scenario.name, e) }
            end
          end
        end
        
        def add_listener(listener)
          @listeners << listener
        end
        
        private
        
        def run_story_ignoring_scenarios(story, world)
          class << world
            def Scenario(name, &block)
              # do nothing
            end
          end
          story.run_in(world)
          class << world
            remove_method(:Scenario)
          end
        end
      end
    end
  end
end
