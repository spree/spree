module Spec
  module Example
    # Base class for customized example groups. Use this if you
    # want to make a custom example group.
    class ExampleGroup
      extend Spec::Example::ExampleGroupMethods
      include Spec::Example::ExampleMethods

      def initialize(defined_description, options={}, &implementation)
        @_options = options
        @_defined_description = defined_description
        @_implementation = implementation || pending_implementation
        @_backtrace = caller
      end
      
    private
      
      def pending_implementation
        error = NotYetImplementedError.new(caller)
        lambda { raise(error) }
      end
    end
  end
end

Spec::ExampleGroup = Spec::Example::ExampleGroup
