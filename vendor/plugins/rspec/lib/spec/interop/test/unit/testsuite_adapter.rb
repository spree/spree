module Test
  module Unit
    class TestSuiteAdapter < TestSuite
      attr_reader :example_group, :examples
      alias_method :tests, :examples
      def initialize(example_group)
        @example_group = example_group
        @examples = example_group.examples
      end

      def name
        example_group.description
      end

      def run(*args)
        return true unless args.empty?
        example_group.run
      end

      def size
        example_group.number_of_examples
      end

      def delete(example)
        examples.delete example
      end

      def empty?
        examples.empty?
      end
    end
  end
end

