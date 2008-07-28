 module Spec
  module Story
    module Runner

      class StoryMediator
        def initialize(step_group, runner, options={})
          @step_group = step_group
          @stories = []
          @runner = runner
          @options = options
        end
        
        def stories
          @stories.collect { |p| p.to_proc }
        end
        
        def create_story(title, narrative)
          @stories << Story.new(title, narrative, @step_group, @options)
        end
        
        def create_scenario(title)
          current_story.add_scenario Scenario.new(title)
        end
        
        def create_given(name)
          current_scenario.add_step Step.new('Given', name)
        end
        
        def create_given_scenario(name)
          current_scenario.add_step Step.new('GivenScenario', name)
        end
        
        def create_when(name)
          current_scenario.add_step Step.new('When', name)
        end
        
        def create_then(name)
          current_scenario.add_step Step.new('Then', name)
        end
        
        def last_step
          current_scenario.last_step
        end
        
        def add_to_last(name)
          last_step.name << name
        end
        
        def run_stories
          stories.each { |story| @runner.instance_eval(&story) }
        end
        
        private
        def current_story
          @stories.last
        end
        
        def current_scenario
          current_story.current_scenario
        end
        
        class Story
          def initialize(title, narrative, step_group, options)
            @title = title
            @narrative = narrative
            @scenarios = []
            @step_group = step_group
            @options = options
          end
          
          def to_proc
            title = @title
            narrative = @narrative
            scenarios = @scenarios.collect { |scenario| scenario.to_proc }
            options = @options.merge(:steps_for => @step_group)
            lambda do
              Story title, narrative, options do
                scenarios.each { |scenario| instance_eval(&scenario) }
              end
            end
          end
          
          def add_scenario(scenario)
            @scenarios << scenario
          end
          
          def current_scenario
            @scenarios.last
          end
        end
        
        class Scenario
          def initialize(name)
            @name = name
            @steps = []
          end
          
          def to_proc
            name = @name
            steps = @steps.collect { |step| step.to_proc }
            lambda do
              Scenario name do
                steps.each { |step| instance_eval(&step) }
              end
            end
          end
          
          def add_step(step)
            @steps << step
          end
          
          def last_step
            @steps.last
          end
        end
        
        class Step
          attr_reader :name
          
          def initialize(type, name)
            @type = type
            @name = name
          end
          
          def to_proc
            type = @type
            name = @name
            lambda do
              send(type, name)
            end
          end
        end
      end
      
    end
  end
end
