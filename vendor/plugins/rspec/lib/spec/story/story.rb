module Spec
  module Story
    class Story
      attr_reader :title, :narrative
      
      def initialize(title, narrative, params = {}, &body)
        @body = body
        @title = title
        @narrative = narrative
        @params = params
      end
      
      def [](key)
        @params[key]
      end
      
      def run_in(obj)
        obj.instance_eval(&@body)
      end
      
      def assign_steps_to(assignee)
        if steps=@params[:steps_for]
          steps = [steps] unless steps.is_a?(Array)
          steps.each do |step|
            if step.is_a?(StepGroup)
              assignee.use(step)
            else
              assignee.use(steps_for(step))
            end
          end
        end
      end
      
      def steps_for(key)
        $rspec_story_steps[key]
      end
    end
  end
end
