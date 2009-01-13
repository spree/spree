require File.dirname(__FILE__) + '/../../../../spec_helper'
require 'spec/runner/formatter/story/progress_bar_formatter'

module Spec
  module Runner
    module Formatter
      module Story
        describe ProgressBarFormatter do
          before :each do
            # given
            @out = StringIO.new
            @out.stub!(:tty?).and_return(true)
            @tweaker = mock('tweaker')
            @tweaker.stub!(:tweak_backtrace)
            @options = mock('options')
            @options.stub!(:colour).and_return(true)
            @options.stub!(:backtrace_tweaker).and_return(@tweaker)

            @formatter = ProgressBarFormatter.new(@options, @out)
          end

          it 'should print some white space before test summary' do
            #when
            @formatter.run_started(1)
            @formatter.run_ended

            #then
            @out.string.should =~ /^\n{2}/
          end

          it "should print how long tests took to complete" do
            #when
            now = Time.now
            future = now+1
            Time.stub!(:now).and_return(now)
            @formatter.run_started(1)
            Time.stub!(:now).and_return(future)
            @formatter.run_ended

            #then
            @out.string.should include("Finished in %f seconds" % (future-now))
          end


          it "should push green dot for passing scenario" do
            #when
            @formatter.scenario_started('','')
            @formatter.step_succeeded('', '')
            @formatter.scenario_ended
            @formatter.story_ended '', ''

            #then
            @out.string.should eql("\e[32m.\e[0m")
          end

          it "should push red F for failure scenario" do
            #when
            @formatter.scenario_started('','')
            @formatter.step_failed('', '')
            @formatter.scenario_failed('', '', '')
            @formatter.story_ended '', ''

            #then
            @out.string.should eql("\e[31mF\e[0m")
          end

          it "should push yellow P for pending scenario" do
            #when
            @formatter.scenario_started('','')
            @formatter.step_pending('', '')
            @formatter.scenario_pending('story', '', '')
            @formatter.story_ended '', ''

            #then
            @out.string.should eql("\e[33mP\e[0m")
          end

        end
      end
    end
  end
end
