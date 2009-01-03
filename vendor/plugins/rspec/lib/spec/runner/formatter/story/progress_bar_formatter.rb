require 'spec/runner/formatter/story/plain_text_formatter'

module Spec
  module Runner
    module Formatter
      module Story
        class ProgressBarFormatter < PlainTextFormatter

          def story_started(title, narrative) end
          def story_ended(title, narrative) end

          def run_started(count)
            @start_time = Time.now
            super
          end
          
          def run_ended
            @output.puts
            @output.puts
            @output.puts "Finished in %f seconds" % (Time.now - @start_time)
            @output.puts
            super
          end

          def scenario_ended
            if @scenario_failed
              @output.print red('F')
              @output.flush
            elsif @scenario_pending
              @output.print yellow('P')
              @output.flush
            else
              @output.print green('.')
              @output.flush
            end
          end

        end
      end
    end
  end
end
