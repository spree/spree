module Sass
  module Script
    class Variable # :nodoc:
      attr_reader :name

      def initialize(name)
        @name = name
      end

      def inspect
        "!#{name}"
      end

      def perform(environment)
        (val = environment.var(name)) && (return val)
        raise SyntaxError.new("Undefined variable: \"!#{name}\".")
      end
    end
  end
end
