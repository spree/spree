module Spec
  module Story
    module Extensions
      module Main
        def Story(title, narrative, params = {}, &body)
          ::Spec::Story::Runner.story_runner.Story(title, narrative, params, &body)
        end
      
        # Calling this deprecated is silly, since it hasn't been released yet. But, for
        # those who are reading this - this will be deleted before the 1.1 release.
        def run_story(*args, &block)
          runner = Spec::Story::Runner::PlainTextStoryRunner.new(*args)
          runner.instance_eval(&block) if block
          runner.run
        end
      
        # Creates (or appends to an existing) a namespaced group of steps for use in Stories
        #
        # == Examples
        #
        #   # Creating a new group
        #   steps_for :forms do
        #     When("user enters $value in the $field field") do ... end
        #     When("user submits the $form form") do ... end
        #   end
        def steps_for(tag, &block)
          steps = rspec_story_steps[tag]
          steps.instance_eval(&block) if block
          steps
        end
      
        # Creates a context for running a Plain Text Story with specific groups of Steps. 
        # Also supports adding arbitrary steps that will only be accessible to
        # the Story being run.
        #
        # == Examples
        #
        #   # Run a Story with one group of steps
        #   with_steps_for :checking_accounts do
        #     run File.dirname(__FILE__) + "/withdraw_cash"
        #   end
        #
        #   # Run a Story, adding steps that are only available for this Story
        #   with_steps_for :accounts do
        #     Given "user is logged in as account administrator"
        #     run File.dirname(__FILE__) + "/reconcile_accounts"
        #   end
        #
        #   # Run a Story with steps from two groups
        #   with_steps_for :checking_accounts, :savings_accounts do
        #     run File.dirname(__FILE__) + "/transfer_money"
        #   end
        #
        #   # Run a Story with a specific Story extension
        #   with_steps_for :login, :navigation do
        #     run File.dirname(__FILE__) + "/user_changes_password", :type => RailsStory
        #   end
        def with_steps_for(*tags, &block)
          steps = Spec::Story::StepGroup.new do
            extend StoryRunnerStepGroupAdapter
          end
          tags.each {|tag| steps << rspec_story_steps[tag]}
          steps.instance_eval(&block) if block
          steps
        end

      private

        module StoryRunnerStepGroupAdapter
          def run(path, options={})
            runner = Spec::Story::Runner::PlainTextStoryRunner.new(path, options)
            runner.steps << self
            runner.run
          end
        end
        
        def rspec_story_steps  # :nodoc:
          $rspec_story_steps ||= Spec::Story::StepGroupHash.new
        end
                
      end
    end
  end
end

include Spec::Story::Extensions::Main