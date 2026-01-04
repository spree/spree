require_relative 'workflows/errors'
require_relative 'workflows/step_response'
require_relative 'workflows/context'
require_relative 'workflows/step'
require_relative 'workflows/hookable'
require_relative 'workflows/base'
require_relative 'workflows/engine'
require_relative 'workflows/execution_result'

module Spree
  module Workflows
    # Subscriber is autoloaded to ensure Spree::Subscriber (its parent class) is available
    autoload :Subscriber, 'spree/workflows/subscriber'

    class << self
      # Find a workflow class by ID
      #
      # Looks up workflow in two ways:
      # 1. Registry (for workflows that explicitly register with workflow_id)
      # 2. Class name convention (e.g., 'order_fulfillment' -> Spree::OrderFulfillmentWorkflow)
      #
      # @param workflow_id [String] the workflow identifier
      # @return [Class] the workflow class
      # @raise [WorkflowNotFoundError] if workflow not found
      def find(workflow_id)
        # Try registry first
        return registry[workflow_id.to_s] if registry.key?(workflow_id.to_s)

        # Try class name convention
        class_name = "Spree::#{workflow_id.to_s.camelize}Workflow"
        begin
          klass = class_name.constantize
          return klass if klass < Base
        rescue NameError
          # Class doesn't exist, fall through to error
        end

        raise WorkflowNotFoundError, "Workflow '#{workflow_id}' not found. " \
          "Define #{class_name} or register with workflow_id '#{workflow_id}'"
      end

      # Register a workflow class (called automatically by workflow_id DSL)
      # @param workflow_id [String] unique identifier
      # @param workflow_class [Class] the workflow class
      def register(workflow_id, workflow_class)
        registry[workflow_id.to_s] = workflow_class
      end

      # List all registered workflow IDs
      # @return [Array<String>]
      def registered_workflows
        registry.keys
      end

      # Clear the registry (for testing)
      def clear_registry!
        @registry = {}
      end

      private

      def registry
        @registry ||= {}
      end
    end
  end
end
