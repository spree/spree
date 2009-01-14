require File.dirname(__FILE__) + '/../../../../spec_helper.rb'
require 'spec/runner/formatter/story/plain_text_formatter'

module Spec
  module Runner
    module Formatter
      module Story
        describe PlainTextFormatter do
          before :each do
            # given
            @out = StringIO.new
            @tweaker = mock('tweaker')
            @tweaker.stub!(:tweak_backtrace)
            @options = mock('options')
            @options.stub!(:colour).and_return(false)
            @options.stub!(:backtrace_tweaker).and_return(@tweaker)
            @formatter = PlainTextFormatter.new(@options, @out)
          end

          it 'should summarize the number of scenarios when the run ends' do
            # when
            @formatter.run_started(3)
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_succeeded('story', 'scenario1')
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_succeeded('story', 'scenario2')
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_succeeded('story', 'scenario3')
            @formatter.run_ended

            # then
            @out.string.should include('3 scenarios')
          end

          it 'should summarize the number of successful scenarios when the run ends' do
            # when
            @formatter.run_started(3)
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_succeeded('story', 'scenario1')
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_succeeded('story', 'scenario2')
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_succeeded('story', 'scenario3')
            @formatter.run_ended

            # then
            @out.string.should include('3 scenarios: 3 succeeded')
          end

          it 'should summarize the number of failed scenarios when the run ends' do
            # when
            @formatter.run_started(3)
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_succeeded('story', 'scenario1')
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_failed('story', 'scenario2', exception_from { raise RuntimeError, 'oops' })
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_failed('story', 'scenario3', exception_from { raise RuntimeError, 'oops' })
            @formatter.run_ended

            # then
            @out.string.should include("3 scenarios: 1 succeeded, 2 failed")
          end

          it 'should end cleanly (no characters on the last line) with successes' do
            # when
            @formatter.run_started(1)
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_succeeded('story', 'scenario')
            @formatter.run_ended

            # then
            @out.string.should =~ /\n\z/
          end

          it 'should end cleanly (no characters on the last line) with failures' do
            # when
            @formatter.run_started(1)
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_failed('story', 'scenario', exception_from { raise RuntimeError, 'oops' })
            @formatter.run_ended

            # then
            @out.string.should =~ /\n\z/
          end

          it 'should end cleanly (no characters on the last line) with pending steps' do
            # when
            @formatter.run_started(1)
            @formatter.scenario_started(nil, nil)
            @formatter.step_pending(:then, 'do pend')
            @formatter.scenario_pending('story', 'scenario', exception_from { raise RuntimeError, 'oops' })
            @formatter.run_ended

            # then
            @out.string.should =~ /\n\z/
          end

          it 'should summarize the number of pending scenarios when the run ends' do
            # when
            @formatter.run_started(3)
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_succeeded('story', 'scenario1')
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_pending('story', 'scenario2', 'message')
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_pending('story', 'scenario3', 'message')
            @formatter.run_ended

            # then
            @out.string.should include("3 scenarios: 1 succeeded, 0 failed, 2 pending")
          end

          it "should only count the first failure in one scenario" do
            # when
            @formatter.run_started(3)
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_succeeded('story', 'scenario1')
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_failed('story', 'scenario2', exception_from { raise RuntimeError, 'oops' })
            @formatter.scenario_failed('story', 'scenario2', exception_from { raise RuntimeError, 'oops again' })
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_failed('story', 'scenario3', exception_from { raise RuntimeError, 'oops' })
            @formatter.run_ended

            # then
            @out.string.should include("3 scenarios: 1 succeeded, 2 failed")
          end

          it "should only count the first pending in one scenario" do
            # when
            @formatter.run_started(3)
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_succeeded('story', 'scenario1')
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_pending('story', 'scenario2', 'because ...')
            @formatter.scenario_pending('story', 'scenario2', 'because ...')
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_pending('story', 'scenario3', 'because ...')
            @formatter.run_ended

            # then
            @out.string.should include("3 scenarios: 1 succeeded, 0 failed, 2 pending")
          end

          it "should only count a failure before the first pending in one scenario" do
            # when
            @formatter.run_started(3)
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_succeeded('story', 'scenario1')
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_pending('story', 'scenario2', exception_from { raise RuntimeError, 'oops' })
            @formatter.scenario_failed('story', 'scenario2', exception_from { raise RuntimeError, 'oops again' })
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_failed('story', 'scenario3', exception_from { raise RuntimeError, 'oops' })
            @formatter.run_ended

            # then
            @out.string.should include("3 scenarios: 1 succeeded, 1 failed, 1 pending")
          end

          it 'should show test summary in red if there were failed scenarios' do
            # when
            @out.stub!(:tty?).and_return(true)
            @options.stub!(:colour).and_return(true)

            @formatter.scenario_started(nil, nil)
            @formatter.scenario_failed('story', 'scenario', exception_from { raise RuntimeError, 'oops' })
            @formatter.run_ended

            # then
            @out.string.should include("\e[31m scenarios: 0 succeeded, 1 failed, 0 pending\e[0m")
          end

          it 'should show test summary in yellow if there are pending scenarios' do
            # when
            @out.stub!(:tty?).and_return(true)
            @options.stub!(:colour).and_return(true)

            @formatter.scenario_started(nil, nil)
            @formatter.scenario_pending('story', 'scenario', '')
            @formatter.run_ended

            # then
            @out.string.should include("\e[32m scenarios: 0 succeeded, 0 failed, 1 pending\e[0m")
          end

          it 'should show test summary in green if all scenarios pass' do
            # when
            @out.stub!(:tty?).and_return(true)
            @options.stub!(:colour).and_return(true)

            @formatter.scenario_started(nil, nil)
            @formatter.scenario_succeeded('story', 'scenario')
            @formatter.run_ended

            # then
            @out.string.should include("\e[32m scenarios: 1 succeeded, 0 failed, 0 pending\e[0m")
          end
        
          it 'should produce details of the first failure each failed scenario when the run ends' do
            # when
            @formatter.run_started(3)
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_succeeded('story', 'scenario1')
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_failed('story', 'scenario2', exception_from { raise RuntimeError, 'oops2' })
            @formatter.scenario_failed('story', 'scenario2', exception_from { raise RuntimeError, 'oops2 - this one should not appear' })
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_failed('story', 'scenario3', exception_from { raise RuntimeError, 'oops3' })
            @formatter.run_ended

            # then
            @out.string.should include("FAILURES:\n")
            @out.string.should include("1) story (scenario2) FAILED")
            @out.string.should include("RuntimeError: oops2")
            @out.string.should_not include("RuntimeError: oops2 - this one should not appear")
            @out.string.should include("2) story (scenario3) FAILED")
            @out.string.should include("RuntimeError: oops3")
          end

          it 'should produce details of the failures in red when the run ends' do
            # when
            @out.stub!(:tty?).and_return(true)
            @options.stub!(:colour).and_return(true)
            @formatter.scenario_started(nil, nil)
            @formatter.scenario_failed('story', 'scenario1', exception_from { raise RuntimeError, 'oops1' })
            @formatter.run_ended

            # then
            @out.string.should =~ /\e\[31m[\n\s]*story \(scenario1\) FAILED\e\[0m/m
            @out.string.should =~ /\e\[31m[\n\s]*RuntimeError: oops1\e\[0m/m
          end

          it 'should produce details of each pending step when the run ends' do
            # when
            @formatter.run_started(2)
            @formatter.story_started('story 1', 'narrative')
            @formatter.scenario_started('story 1', 'scenario 1')
            @formatter.step_pending(:given, 'todo 1', [])
            @formatter.story_started('story 2', 'narrative')
            @formatter.scenario_started('story 2', 'scenario 2')
            @formatter.step_pending(:given, 'todo 2', [])
            @formatter.run_ended

            # then
            @out.string.should include("Pending Steps:\n")
            @out.string.should include("1) story 1 (scenario 1): todo 1")
            @out.string.should include("2) story 2 (scenario 2): todo 2")
          end

          it 'should document a story title and narrative' do
            # when
            @formatter.story_started 'story', 'narrative'
            @formatter.story_ended 'story', 'narrative'

            # then
            @out.string.should include("Story: story\n\n  narrative")
          end

          it 'should document a scenario name' do
            # when
            @formatter.scenario_started 'story', 'scenario'
            @formatter.scenario_ended
            @formatter.story_ended '', ''

            # then
            @out.string.should include("\n\n  Scenario: scenario")
          end

          it 'should document a step by sentence-casing its name' do
            # when
            @formatter.step_succeeded :given, 'a context'
            @formatter.step_succeeded :when, 'an event'
            @formatter.step_succeeded :then, 'an outcome'
            @formatter.scenario_ended
            @formatter.story_ended '', ''

            # then
            @out.string.should include("\n\n    Given a context\n\n    When an event\n\n    Then an outcome")
          end

          it 'should document additional givens using And' do
            # when
            @formatter.step_succeeded :given, 'step 1'
            @formatter.step_succeeded :given, 'step 2'
            @formatter.step_succeeded :given, 'step 3'
            @formatter.scenario_ended
            @formatter.story_ended '', ''

            # then
            @out.string.should include("    Given step 1\n    And step 2\n    And step 3")
          end

          it 'should document additional events using And' do
            # when
            @formatter.step_succeeded :when, 'step 1'
            @formatter.step_succeeded :when, 'step 2'
            @formatter.step_succeeded :when, 'step 3'
            @formatter.scenario_ended
            @formatter.story_ended '', ''

            # then
            @out.string.should include("    When step 1\n    And step 2\n    And step 3")
          end

          it 'should document additional outcomes using And' do
            # when
            @formatter.step_succeeded :then, 'step 1'
            @formatter.step_succeeded :then, 'step 2'
            @formatter.step_succeeded :then, 'step 3'
            @formatter.scenario_ended
            @formatter.story_ended '', ''

            # then
            @out.string.should include("    Then step 1\n    And step 2\n    And step 3")
          end

          it 'should document a GivenScenario followed by a Given using And' do
            # when
            @formatter.step_succeeded :'given scenario', 'a scenario'
            @formatter.step_succeeded :given, 'a context'
            @formatter.scenario_ended
            @formatter.story_ended '', ''

            # then
            @out.string.should include("    Given scenario a scenario\n    And a context")
          end

          it 'should document steps with replaced params' do
            @formatter.step_succeeded :given, 'a $coloured dog with $n legs', 'pink', 21
            @formatter.scenario_ended
            @formatter.story_ended '', ''
            @out.string.should include("  Given a pink dog with 21 legs")
          end

          it 'should document steps that include dollar signs ($)' do
            @formatter.step_succeeded :given, 'kicks that cost $$amount', 50
            @formatter.scenario_ended
            @formatter.story_ended '', ''
            @out.string.should include("Given kicks that cost $50")
          end

          it 'should document regexp steps with replaced params' do
            @formatter.step_succeeded :given, /a (pink|blue) dog with (.*) legs/, 'pink', 21
            @formatter.scenario_ended
            @formatter.story_ended '', ''
            @out.string.should include("  Given a pink dog with 21 legs")
          end

          it 'should document regex steps that include dollar signs ($)' do
            @formatter.step_succeeded :given, /kicks that cost \$(\d+)/, 50
            @formatter.scenario_ended
            @formatter.story_ended '', ''
            @out.string.should include("Given kicks that cost $50")
          end

          it "should append PENDING for the first pending step" do
            @formatter.scenario_started('','')
            @formatter.scenario_ended
            @formatter.story_ended '', ''
            @formatter.step_pending(:given, 'a context')
            @formatter.scenario_ended
            @formatter.story_ended '', ''

            @out.string.should include('Given a context (PENDING)')
          end

          it "should append PENDING for pending after already pending" do
            @formatter.scenario_started('','')
            @formatter.step_pending(:given, 'a context')
            @formatter.step_pending(:when, 'I say hey')
            @formatter.scenario_ended
            @formatter.story_ended '', ''

            @out.string.should include('When I say hey (PENDING)')
          end

          it "should append FAILED for the first failiure" do
            @formatter.scenario_started('','')
            @formatter.step_failed(:given, 'a context')
            @formatter.scenario_ended
            @formatter.story_ended '', ''

            @out.string.should include('Given a context (FAILED)')
          end

          it "should append SKIPPED for the second failiure" do
            @formatter.scenario_started('','')
            @formatter.step_failed(:given, 'a context')
            @formatter.step_failed(:when, 'I say hey')
            @formatter.scenario_ended
            @formatter.story_ended '', ''

            @out.string.should include('When I say hey (SKIPPED)')
          end

          it "should append SKIPPED for a failure after PENDING" do
            @formatter.scenario_started('','')
            @formatter.step_pending(:given, 'a context')
            @formatter.step_failed(:when, 'I say hey')
            @formatter.scenario_ended
            @formatter.story_ended '', ''

            @out.string.should include('When I say hey (SKIPPED)')
          end

          it "should print steps which succeeded in green" do
            @out.stub!(:tty?).and_return(true)
            @options.stub!(:colour).and_return(true)

            @formatter.scenario_started('','')
            @formatter.step_succeeded(:given, 'a context')
            @formatter.scenario_ended
            @formatter.story_ended '', ''

            @out.string.should =~ /\e\[32m[\n\s]+Given a context\e\[0m/m
          end

          it "should print failed steps in red" do
            @out.stub!(:tty?).and_return(true)
            @options.stub!(:colour).and_return(true)

            @formatter.scenario_started('','')
            @formatter.step_failed(:given, 'a context')
            @formatter.scenario_ended
            @formatter.story_ended '', ''

            @out.string.should =~ /\e\[31m[\n\s]+Given a context\e\[0m/m
          end

          it "should print ' (FAILED)' in red" do
            @out.stub!(:tty?).and_return(true)
            @options.stub!(:colour).and_return(true)

            @formatter.scenario_started('','')
            @formatter.step_failed(:given, 'a context')
            @formatter.scenario_ended
            @formatter.story_ended '', ''

            @out.string.should =~ /\e\[31m \(FAILED\)\e\[0m/
          end

          it "should print pending steps in yellow" do
            @out.stub!(:tty?).and_return(true)
            @options.stub!(:colour).and_return(true)

            @formatter.scenario_started('','')
            @formatter.step_pending(:given, 'a context')
            @formatter.scenario_ended
            @formatter.story_ended '', ''

            @out.string.should =~ /\e\[33m[\n\s]+Given a context\e\[0m/m
          end

          it "should print ' (PENDING)' in yellow" do
            @out.stub!(:tty?).and_return(true)
            @options.stub!(:colour).and_return(true)

            @formatter.scenario_started('','')
            @formatter.step_pending(:given, 'a context')
            @formatter.scenario_ended
            @formatter.story_ended '', ''

            @out.string.should =~ /\e\[33m \(PENDING\)\e\[0m/
          end

          it "should print a scenario in red if any of its steps fail" do
            @out.stub!(:tty?).and_return(true)
            @options.stub!(:colour).and_return(true)

            @formatter.scenario_started('title','narrative')
            @formatter.step_failed(:given, 'a context')
            @formatter.scenario_failed('story', 'scenario1', exception_from { raise RuntimeError, 'oops1' })
            @formatter.story_ended('title','narrative')
            @out.string.should include("\e[31m\n\n  Scenario: narrative\e[0m")
          end
          
          it "should print a scenario in yellow if its steps are pending" do
             @out.stub!(:tty?).and_return(true)
             @options.stub!(:colour).and_return(true)

             @formatter.scenario_started('title','narrative')
             @formatter.step_pending(:given, 'a context')
             @formatter.scenario_ended
             @formatter.story_ended('','')
             @out.string.should include("\e[33m\n\n  Scenario: narrative\e[0m")
          end
   
          it "should print a story in red if any of its scenarios fail" do
            @out.stub!(:tty?).and_return(true)
            @options.stub!(:colour).and_return(true)
            
            @formatter.story_started('story', 'narrative')
            @formatter.scenario_started('','')
            @formatter.step_failed(:given, 'a context')
            @formatter.scenario_failed('story', 'scenario1', exception_from { raise RuntimeError, 'oops1' })
            @formatter.story_ended('story', 'narrative')
            @out.string.should include("\e[31mStory: story\n\n  narrative\e[0m")
          end

          it "should print a story in green if all its scenarios succeed" do
            @out.stub!(:tty?).and_return(true)
            @options.stub!(:colour).and_return(true)
            
            @formatter.story_started('story', 'narrative')
            @formatter.scenario_started('','')
            @formatter.step_succeeded(:given, 'a context')
            @formatter.scenario_succeeded('story', 'scenario1')
            @formatter.story_ended('story', 'narrative')
            @out.string.should include("\e[32mStory: story\n\n  narrative\e[0m")
          end

          it "should print a story in yellow if all its scenarios are pending" do
            @out.stub!(:tty?).and_return(true)
            @options.stub!(:colour).and_return(true)
            
            @formatter.story_started('story', 'narrative')
            @formatter.scenario_started('','')
            @formatter.step_pending(:given, 'a context')
            @formatter.scenario_pending('story', 'scenario1','pending')
            @formatter.story_ended('story', 'narrative')
            @out.string.should include("\e[33mStory: story\n\n  narrative\e[0m")
          end
          
          it "should print skipped steps in yellow if the scenario is already pending" do
            @out.stub!(:tty?).and_return(true)
            @options.stub!(:colour).and_return(true)

            @formatter.scenario_started('','')
            @formatter.step_pending(:given, 'a context')
            @formatter.step_failed(:when, 'I say hey')
            @formatter.scenario_ended
            @formatter.story_ended '', ''

            @out.string.should =~ /\e\[33m[\n\s]+When I say hey\e\[0m/m
          end

          it "should print ' (SKIPPED)' in yellow if the scenario is already pending" do
            @out.stub!(:tty?).and_return(true)
            @options.stub!(:colour).and_return(true)

            @formatter.scenario_started('','')
            @formatter.step_pending(:given, 'a context')
            @formatter.step_failed(:when, 'I say hey')
            @formatter.scenario_ended
            @formatter.story_ended '', ''

            @out.string.should =~ /\e\[33m \(SKIPPED\)\e\[0m/
          end

          it "should print skipped steps in red if the scenario has already failed" do
            @out.stub!(:tty?).and_return(true)
            @options.stub!(:colour).and_return(true)

            @formatter.scenario_started('','')
            @formatter.step_failed(:given, 'a context')
            @formatter.step_failed(:when, 'I say hey')
            @formatter.scenario_ended
            @formatter.story_ended '', ''

            @out.string.should =~ /\e\[31m[\n\s]+When I say hey\e\[0m/m
          end

          it "should print ' (SKIPPED)' in red if the scenario has already failed" do
            @out.stub!(:tty?).and_return(true)
            @options.stub!(:colour).and_return(true)

            @formatter.scenario_started('','')
            @formatter.step_failed(:given, 'a context')
            @formatter.step_failed(:when, 'I say hey')
            @formatter.scenario_failed('story', 'scenario1', exception_from { raise RuntimeError, 'oops1' })         
            @formatter.story_ended('','')

            @out.string.should =~ /\e\[31m \(SKIPPED\)\e\[0m/m
          end

          it 'should print some white space after each story' do
            # when
            @formatter.story_ended 'title', 'narrative'

            # then
            @out.string.should include("\n\n")
          end

          it "should print nothing for collected_steps" do
            @formatter.collected_steps(['Given a $coloured $animal', 'Given a $n legged eel'])
            @out.string.should == ("")
          end

          it "should ignore messages it doesn't care about" do
            lambda {
              @formatter.this_method_does_not_exist
            }.should_not raise_error
          end
        end
      end
    end
  end
end
