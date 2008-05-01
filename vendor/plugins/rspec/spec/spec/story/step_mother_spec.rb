require File.dirname(__FILE__) + '/story_helper'

module Spec
  module Story
    describe StepMother do
      it 'should store a step by name and type' do
        # given
        step_mother = StepMother.new
        step = Step.new("a given", &lambda {})
        step_mother.store(:given, step)
        
        # when
        found = step_mother.find(:given, "a given")
        
        # then
        found.should == step
      end
      
      it 'should NOT raise an error if a step is missing' do
        # given
        step_mother = StepMother.new
        
        # then
        lambda do
          # when
          step_mother.find(:given, "doesn't exist")
        end.should_not raise_error
      end
      
      it "should create a default step which raises a pending error" do
        # given
        step_mother = StepMother.new
        
        # when
        step = step_mother.find(:given, "doesn't exist")
        
        # then
        step.should be_an_instance_of(Step)
        
        lambda do
          step.perform(Object.new, "doesn't exist")
        end.should raise_error(Spec::Example::ExamplePendingError, /Unimplemented/)
      end
      
      it 'should clear itself' do
        # given
        step_mother = StepMother.new
        step = Step.new("a given") do end
        step_mother.store(:given, step)

        # when
        step_mother.clear
        
        # then
        step_mother.should be_empty
      end
      
      it "should use assigned steps" do
        step_mother = StepMother.new
        
        step = Step.new('step') {}
        step_group = StepGroup.new
        step_group.add(:given, step)
        
        step_mother.use(step_group)
                
        step_mother.find(:given, "step").should equal(step)
      end

    end
  end
end
