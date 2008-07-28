require 'spec/runner/formatter/base_text_formatter'

module Spec
  module Runner
    module Formatter
      class FailingExampleGroupsFormatter < BaseTextFormatter
        def example_failed(example, counter, failure)
          if @example_group
            description_parts = @example_group.description_parts.collect do |description|
              description =~ /(.*) \(druby.*\)$/ ? $1 : description
            end
            @output.puts ::Spec::Example::ExampleGroupMethods.description_text(*description_parts)

            @output.flush
            @example_group = nil
          end
        end

        def dump_failure(counter, failure)
        end

        def dump_summary(duration, example_count, failure_count, pending_count)
        end
      end
    end
  end
end
