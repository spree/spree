module Spec
  module Runner
    # Parses a spec file and finds the nearest example for a given line number.
    class SpecParser
      attr_reader :best_match

      def initialize
        @best_match = {}
      end

      def spec_name_for(file, line_number)
        best_match.clear
        file = File.expand_path(file)
        rspec_options.example_groups.each do |example_group|
          consider_example_groups_for_best_match example_group, file, line_number

          example_group.examples.each do |example|
            consider_example_for_best_match example, example_group, file, line_number
          end
        end
        if best_match[:example_group]
          if best_match[:example]
            "#{best_match[:example_group].description} #{best_match[:example].description}"
          else
            best_match[:example_group].description
          end
        else
          nil
        end
      end

    protected

      def consider_example_groups_for_best_match(example_group, file, line_number)
        parsed_backtrace = parse_backtrace(example_group.registration_backtrace)
        parsed_backtrace.each do |example_file, example_line|
          if is_best_match?(file, line_number, example_file, example_line)
            best_match.clear
            best_match[:example_group] = example_group
            best_match[:line] = example_line
          end
        end
      end

      def consider_example_for_best_match(example, example_group, file, line_number)
        parsed_backtrace = parse_backtrace(example.implementation_backtrace)
        parsed_backtrace.each do |example_file, example_line|
          if is_best_match?(file, line_number, example_file, example_line)
            best_match.clear
            best_match[:example_group] = example_group
            best_match[:example] = example
            best_match[:line] = example_line
          end
        end
      end

      def is_best_match?(file, line_number, example_file, example_line)
        file == File.expand_path(example_file) &&
        example_line <= line_number &&
        example_line > best_match[:line].to_i
      end

      def parse_backtrace(backtrace)
        backtrace.collect do |trace_line|
          split_line = trace_line.split(':')
          [split_line[0], Integer(split_line[1])]
        end
      end
    end
  end
end
