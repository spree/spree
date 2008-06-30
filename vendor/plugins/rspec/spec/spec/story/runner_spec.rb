require File.dirname(__FILE__) + '/story_helper'
require 'spec/runner/formatter/story/plain_text_formatter'
require 'spec/runner/formatter/story/html_formatter'

module Spec
  module Story
    describe Runner, "module" do
      before(:each) do
        @world_creator = World.dup
        @runner_module = Runner.dup
        @runner_module.instance_eval {@story_runner = nil}
        @runner_module.stub!(:register_exit_hook)
      end
      
      def create_options(args=[])
        Spec::Runner::OptionParser.parse(args, StringIO.new, StringIO.new)
      end
      
      it 'should wire up a singleton StoryRunner' do
        @runner_module.story_runner.should_not be_nil
      end
      
      it 'should set its options based on ARGV' do
        # given
        @runner_module.should_receive(:run_options).and_return(
          create_options(['--dry-run'])
        )

        # when
        options = @runner_module.run_options
        
        # then
        options.dry_run.should be_true
      end
      
      describe "initialization" do
        
        before(:each) do
          # given
          @story_runner = mock('story runner', :null_object => true)
          @scenario_runner = mock('scenario runner', :null_object => true)
          @world_creator = mock('world', :null_object => true)
        
          @runner_module.stub!(:world_creator).and_return(@world_creator)
          @runner_module.stub!(:create_story_runner).and_return(@story_runner)
          @runner_module.stub!(:scenario_runner).and_return(@scenario_runner)
        end

        it 'should add a reporter to the runner classes' do
          @runner_module.should_receive(:run_options).and_return(
            create_options
          )
        
          # expect
          @world_creator.should_receive(:add_listener).with(an_instance_of(Spec::Runner::Formatter::Story::PlainTextFormatter))
          @story_runner.should_receive(:add_listener).with(an_instance_of(Spec::Runner::Formatter::Story::PlainTextFormatter))
          @scenario_runner.should_receive(:add_listener).with(an_instance_of(Spec::Runner::Formatter::Story::PlainTextFormatter))
        
          # when
          @runner_module.story_runner
        end
      
        it 'should add a documenter to the runner classes if one is specified' do
        
          @runner_module.should_receive(:run_options).and_return(
            create_options(["--format","html"])
          )

          # expect
          @world_creator.should_receive(:add_listener).with(an_instance_of(Spec::Runner::Formatter::Story::HtmlFormatter))
          @story_runner.should_receive(:add_listener).with(an_instance_of(Spec::Runner::Formatter::Story::HtmlFormatter))
          @scenario_runner.should_receive(:add_listener).with(an_instance_of(Spec::Runner::Formatter::Story::HtmlFormatter))
        
          # when
          @runner_module.story_runner
        end
      
        it 'should add any registered listener to the runner classes' do
          # given
          listener = Object.new
        
          # expect
          @world_creator.should_receive(:add_listener).with(listener)
          @story_runner.should_receive(:add_listener).with(listener)
          @scenario_runner.should_receive(:add_listener).with(listener)
        
          # when
          @runner_module.register_listener listener
        end
      end
      end
  end
end
