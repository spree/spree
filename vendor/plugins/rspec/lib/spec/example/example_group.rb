module Spec
  module Example
    # The superclass for all regular RSpec examples.
    class ExampleGroup
      extend Spec::Example::ExampleGroupMethods
      include Spec::Example::ExampleMethods

      def initialize(defined_description, &implementation)
        @_defined_description = defined_description
        @_implementation = implementation
      end
    end
  end
end

Spec::ExampleGroup = Spec::Example::ExampleGroup
