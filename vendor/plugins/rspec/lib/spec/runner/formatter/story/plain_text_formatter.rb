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
            
            @pre_story_pending_count = 0
            @pre_story_successful_count = 0
            
            @failed_scenarios = []
            @pending_steps = []
            @previous_type = nil 
            
            @scenario_body_text = ""
            @story_body_text = ""
            
            @scenario_head_text = ""
            @story_head_text = ""
                  
            @scenario_failed = false
            @story_failed = false
          end
        
          def run_started(count)
            @count = count
            @output.puts "Running #@count scenarios\n\n"
          end

          def story_started(title, narrative)
            @pre_story_pending_count = @pending_scenario_count
            @pre_story_successful_count = @successful_scenario_count
            
            @current_story_title = title
            @story_failed = false
            @story_body_text = ""
            @story_head_text = "Story: #{title}\n\n"

            narrative.each_line do |line|
              @story_head_text += "  "
              @story_head_text += line
            end
          end
        
          def story_ended(title, narrative)
            if @story_failed
              @output.print red(@story_head_text)
            elsif @pre_story_successful_count == @successful_scenario_count && 
                  @pending_scenario_count >= @pre_story_pending_count
              @output.print yellow(@story_head_text)
            else              
              @output.print green(@story_head_text)
            end
            @output.print @story_body_text
            @output.puts
            @output.puts
          end

          def scenario_started(story_title, scenario_name)
            @current_scenario_name = scenario_name
            @scenario_already_failed = false
            @scenario_head_text = "\n\n  Scenario: #{scenario_name}"
            @scenario_body_text = ""
            @scenario_ok = true
            @scenario_pending = false
            @scenario_failed = false
          end
        
          def scenario_succeeded(story_title, scenario_name)
            @successful_scenario_count += 1
            scenario_ended
          end
        
          def scenario_failed(story_title, scenario_name, err)
            @options.backtrace_tweaker.tweak_backtrace(err)
            @failed_scenarios << [story_title, scenario_name, err] unless @scenario_already_failed
            @scenario_already_failed = true
            @story_failed = true
            @scenario_failed = true
            scenario_ended
          end
        
          def scenario_pending(story_title, scenario_name, msg)
            @pending_scenario_count += 1 unless @scenario_already_failed
            @scenario_pending = true
            @scenario_already_failed = true
            scenario_ended
          end
        
          def scenario_ended
            if @scenario_failed
              @story_body_text += red(@scenario_head_text)
            elsif @scenario_pending
              @story_body_text += yellow(@scenario_head_text)
            else
              @story_body_text += green(@scenario_head_text)
            end
            @story_body_text += @scenario_body_text
          end
          
          def run_ended
            summary_text = "#@count scenarios: #@successful_scenario_count succeeded, #{@failed_scenarios.size} failed, #@pending_scenario_count pending"
            if !@failed_scenarios.empty?
              @output.puts red(summary_text)
            elsif !@pending_steps.empty?
              @output.puts yellow(summary_text)
            else
              @output.puts green(summary_text)
            end
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
                @output.print "\n    #{i+1}) "
                @output.print red("#{title} (#{scenario_name}) FAILED")
                @output.print red("\n    #{err.class}: #{err.message}")
                @output.print "\n    #{err.backtrace.join("\n")}\n"
              end
            end            
          end

          def step_upcoming(type, description, *args)
          end
                  
          def step_succeeded(type, description, *args)
            found_step(type, description, false, false, *args)
          end
        
          def step_pending(type, description, *args)
            found_step(type, description, false, true, *args)
            @pending_steps << [@current_story_title, @current_scenario_name, description]
            @scenario_body_text +=  yellow(" (PENDING)")
            @scenario_pending = true
            @scenario_ok = false
          end
        
          def step_failed(type, description, *args)
            found_step(type, description, true, @scenario_pending, *args)
            if @scenario_pending
              @scenario_body_text +=  yellow(" (SKIPPED)")
            else
              @scenario_body_text +=  red(@scenario_ok ? " (FAILED)" : " (SKIPPED)")
            end
            @scenario_ok = false
          end
          
          def collected_steps(steps)
          end
          
          def method_missing(sym, *args, &block) #:nodoc:
            # noop - ignore unknown messages
          end

        private

          def found_step(type, description, failed, pending, *args)
            desc_string = description.step_name
            arg_regexp = description.arg_regexp
            text = if(type == @previous_type)
              "\n    And "
            else
              "\n\n    #{type.to_s.capitalize} "
            end
            i = -1
            text << desc_string.gsub(arg_regexp) { |param| args[i+=1] }
            if pending
              @scenario_body_text += yellow(text)
            else
              @scenario_body_text += (failed ? red(text) : green(text))
            end

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
