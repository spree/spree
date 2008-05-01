require File.dirname(__FILE__) + '/story_helper'

module Spec
  module Story
    describe Runner, "module" do
      def dev_null
        io = StringIO.new
        def io.write(str)
          str.to_s.size
        end
        return io
      end
      
      before :each do
        Kernel.stub!(:at_exit)
        @stdout, $stdout = $stdout, dev_null
        @argv = Array.new(ARGV)
        @runner_module = Runner.dup
        @world_creator = World.dup
        @runner_module.module_eval { @run_options = @story_runner = @scenario_runner = @world_creator = nil }
      end
      
      after :each do
        $stdout = @stdout
        ARGV.replace @argv
        @runner_module.module_eval { @run_options = @story_runner = @scenario_runner = @world_creator = nil }
      end
      
      it 'should wire up a singleton StoryRunner' do
        @runner_module.story_runner.should_not be_nil
      end
      
      it 'should set its options based on ARGV' do
        # given
        ARGV << '--dry-run'
        
        # when
        options = @runner_module.run_options
        
        # then
        options.dry_run.should be_true
      end

      it 'should add a reporter to the runner classes' do
        # given
        story_runner = mock('story runner', :null_object => true)
        scenario_runner = mock('scenario runner', :null_object => true)
        world_creator = mock('world', :null_object => true)
        
        @runner_module::class_eval { @world_creator = world_creator }
        @runner_module::StoryRunner.stub!(:new).and_return(story_runner)
        @runner_module::ScenarioRunner.stub!(:new).and_return(scenario_runner)
        
        # expect
        world_creator.should_receive(:add_listener).with(an_instance_of(Spec::Runner::Formatter::Story::PlainTextFormatter))
        story_runner.should_receive(:add_listener).with(an_instance_of(Spec::Runner::Formatter::Story::PlainTextFormatter))
        scenario_runner.should_receive(:add_listener).with(an_instance_of(Spec::Runner::Formatter::Story::PlainTextFormatter))
        
        # when
        @runner_module.story_runner
      end
      
      it 'should add a documenter to the runner classes if one is specified' do
        # given
        ARGV << "--format" << "html"
        story_runner = mock('story runner', :null_object => true)
        scenario_runner = mock('scenario runner', :null_object => true)
        world_creator = mock('world', :null_object => true)
        
        @runner_module::class_eval { @world_creator = world_creator }
        @runner_module::StoryRunner.stub!(:new).and_return(story_runner)
        @runner_module::ScenarioRunner.stub!(:new).and_return(scenario_runner)
        
        # expect
        world_creator.should_receive(:add_listener).with(an_instance_of(Spec::Runner::Formatter::Story::HtmlFormatter))
        story_runner.should_receive(:add_listener).with(an_instance_of(Spec::Runner::Formatter::Story::HtmlFormatter))
        scenario_runner.should_receive(:add_listener).with(an_instance_of(Spec::Runner::Formatter::Story::HtmlFormatter))
        
        # when
        @runner_module.story_runner
      end
      
      it 'should add any registered listener to the runner classes' do
        # given
        ARGV << "--format" << "html"
        story_runner = mock('story runner', :null_object => true)
        scenario_runner = mock('scenario runner', :null_object => true)
        world_creator = mock('world', :null_object => true)
        
        @runner_module::class_eval { @world_creator = world_creator }
        @runner_module::StoryRunner.stub!(:new).and_return(story_runner)
        @runner_module::ScenarioRunner.stub!(:new).and_return(scenario_runner)
        
        listener = Object.new
        
        # expect
        world_creator.should_receive(:add_listener).with(listener)
        story_runner.should_receive(:add_listener).with(listener)
        scenario_runner.should_receive(:add_listener).with(listener)
        
        # when
        @runner_module.register_listener listener
      end
    end
  end
end
