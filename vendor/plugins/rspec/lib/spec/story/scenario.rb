
module Spec
  module Story
    class Scenario
      attr_accessor :name, :body, :story
      
      def initialize(story, name, &body)
        @story = story
        @name = name
        @body = body
      end
    end
  end
end
