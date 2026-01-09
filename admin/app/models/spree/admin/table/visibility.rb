module Spree
  module Admin
    class Table
      # Shared visibility logic for components with conditional display
      module Visibility
        extend ActiveSupport::Concern

        # Check if component is visible for the given context
        # @param context [Object, nil] view context with access to helper methods
        # @return [Boolean]
        def visible?(context = nil)
          return true if condition.nil?
          return condition unless condition.respond_to?(:call)

          context&.respond_to?(:instance_exec) ? context.instance_exec(&condition) : condition.call(context)
        end
      end
    end
  end
end
