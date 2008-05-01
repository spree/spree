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
        if @params[:steps]
          assignee.use(@params[:steps])
        else
          case keys = @params[:steps_for]
          when Symbol
            keys = [keys]
          when nil
            keys = []
          end
          keys.each do |key|
            assignee.use(steps_for(key))
          end
        end
      end
      
      def steps_for(key)
        $rspec_story_steps[key]
      end
    end
  end
end
