module Spec
  module Story
    class StepMother
      def initialize
        @steps = StepGroup.new
      end
      
      def use(new_step_group)
        @steps << new_step_group
      end
      
      def store(type, step)
        @steps.add(type, step)
      end
      
      def find(type, name)
        if @steps.find(type, name).nil?
          @steps.add(type,
          Step.new(name) do
            raise Spec::Example::ExamplePendingError.new("Unimplemented step: #{name}")
          end
          )
        end
        @steps.find(type, name)
      end
      
      def clear
        @steps.clear
      end
      
      def empty?
        @steps.empty?
      end
      
    end
  end
end
