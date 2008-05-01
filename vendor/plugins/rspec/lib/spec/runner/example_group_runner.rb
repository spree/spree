module Spec
  module Runner
    class ExampleGroupRunner
      def initialize(options)
        @options = options
      end

      def load_files(files)
        # It's important that loading files (or choosing not to) stays the
        # responsibility of the ExampleGroupRunner. Some implementations (like)
        # the one using DRb may choose *not* to load files, but instead tell
        # someone else to do it over the wire.
        files.each do |file|
          load file
        end
      end

      def run
        prepare
        success = true
        example_groups.each do |example_group|
          success = success & example_group.run
        end
        return success
      ensure
        finish
      end

      protected
      def prepare
        reporter.start(number_of_examples)
        example_groups.reverse! if reverse
      end

      def finish
        reporter.end
        reporter.dump
      end

      def reporter
        @options.reporter
      end

      def reverse
        @options.reverse
      end

      def example_groups
        @options.example_groups
      end

      def number_of_examples
        @options.number_of_examples
      end
    end
    # TODO: BT - Deprecate BehaviourRunner?
    BehaviourRunner = ExampleGroupRunner
  end
end