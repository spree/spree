require 'spec/runner/formatter/base_text_formatter'

module Spec
  module Runner
    module Formatter
      module Story
        class PlainTextFormatter < BaseTextFormatter
          def initialize(options, where)
            super
            @successful_scenario_count = 0
            @pending_scenario_count = 0
            @failed_scenarios = []
            @pending_steps = []
            @previous_type = nil
          end
        
          def run_started(count)
            @count = count
            @output.puts "Running #@count scenarios\n\n"
          end

          def story_started(title, narrative)
            @current_story_title = title
            @output.puts "Story: #{title}\n\n"
            narrative.each_line do |line|
              @output.print "  "
              @output.print line
            end
          end
        
          def story_ended(title, narrative)
            @output.puts
            @output.puts
          end

          def scenario_started(story_title, scenario_name)
            @current_scenario_name = scenario_name
            @scenario_already_failed = false
            @output.print "\n\n  Scenario: #{scenario_name}"
            @scenario_ok = true
          end
        
          def scenario_succeeded(story_title, scenario_name)
            @successful_scenario_count += 1
          end
        
          def scenario_failed(story_title, scenario_name, err)
            @options.backtrace_tweaker.tweak_backtrace(err)
            @failed_scenarios << [story_title, scenario_name, err] unless @scenario_already_failed
            @scenario_already_failed = true
          end
        
          def scenario_pending(story_title, scenario_name, msg)
            @pending_scenario_count += 1 unless @scenario_already_failed
            @scenario_already_failed = true
          end
        
          def run_ended
            @output.puts "#@count scenarios: #@successful_scenario_count succeeded, #{@failed_scenarios.size} failed, #@pending_scenario_count pending"
            unless @pending_steps.empty?
              @output.puts "\nPending Steps:"
              @pending_steps.each_with_index do |pending, i|
                story_name, scenario_name, msg = pending
                @output.puts "#{i+1}) #{story_name} (#{scenario_name}): #{msg}"
              end
            end
            unless @failed_scenarios.empty?
              @output.print "\nFAILURES:"
              @failed_scenarios.each_with_index do |failure, i|
                title, scenario_name, err = failure
                @output.print %[
    #{i+1}) #{title} (#{scenario_name}) FAILED
    #{err.class}: #{err.message}
    #{err.backtrace.join("\n")}
]
              end
            end            
          end

          def step_upcoming(type, description, *args)
          end
                  
          def step_succeeded(type, description, *args)
            found_step(type, description, false, *args)
          end
        
          def step_pending(type, description, *args)
            found_step(type, description, false, *args)
            @pending_steps << [@current_story_title, @current_scenario_name, description]
            @output.print " (PENDING)"
            @scenario_ok = false
          end
        
          def step_failed(type, description, *args)
            found_step(type, description, true, *args)
            @output.print red(@scenario_ok ? " (FAILED)" : " (SKIPPED)")
            @scenario_ok = false
          end
          
          def collected_steps(steps)
          end
          
          def method_missing(sym, *args, &block) #:nodoc:
            # noop - ignore unknown messages
          end

        private

          def found_step(type, description, failed, *args)
            desc_string = description.step_name
            arg_regexp = description.arg_regexp
            text = if(type == @previous_type)
              "\n    And "
            else
              "\n\n    #{type.to_s.capitalize} "
            end
            i = -1
            text << desc_string.gsub(arg_regexp) { |param| args[i+=1] }
            @output.print(failed ? red(text) : green(text))

            if type == :'given scenario'
              @previous_type = :given
            else
              @previous_type = type
            end
          end
        end
      end
    end
  end
end
