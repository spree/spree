module Spec
  module Story
    module Runner
      class PlainTextStoryRunner
        # You can initialize a PlainTextStoryRunner with the path to the
        # story file or a block, in which you can define the path using load.
        #
        # == Examples
        #   
        #   PlainTextStoryRunner.new('path/to/file')
        #
        #   PlainTextStoryRunner.new do |runner|
        #     runner.load 'path/to/file'
        #   end
        def initialize(*args)
          @options = Hash === args.last ? args.pop : {}
          @story_file = args.empty? ? nil : args.shift
          yield self if block_given?
        end
        
        def []=(key, value)
          @options[key] = value
        end
        
        def load(path)
          @story_file = path
        end
        
        def run(story_runner=Spec::Story::Runner.story_runner)
          raise "You must set a path to the file with the story. See the RDoc." if @story_file.nil?
          mediator = Spec::Story::Runner::StoryMediator.new(steps, story_runner, @options)
          parser = Spec::Story::Runner::StoryParser.new(mediator)

          story_text = File.read(@story_file)          
          parser.parse(story_text.split("\n"))

          mediator.run_stories
        end
        
        def steps
          @step_group ||= Spec::Story::StepGroup.new
          yield @step_group if block_given?
          @step_group
        end
      end
    end
  end
end
