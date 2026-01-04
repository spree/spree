module Spree
  module Workflows
    # Thin wrapper around WorkflowExecution for API compatibility.
    # Most functionality now lives directly on the model.
    #
    # @example
    #   result = MyWorkflow.run(input: { order_id: 1 })
    #   result.success?          # => true
    #   result.output             # => { ... }
    #   result.transaction_id     # => "uuid"
    #
    class ExecutionResult < SimpleDelegator
      def initialize(execution)
        super(execution)
      end

      # Access the underlying execution record
      # @return [Spree::WorkflowExecution]
      def execution
        __getobj__
      end

      # Reload from database
      # @return [self]
      def reload
        __getobj__.reload
        self
      end

      # Hash representation for serialization
      # @return [Hash]
      def to_h
        execution.to_result_hash
      end

      def as_json(options = nil)
        to_h.as_json(options)
      end
    end
  end
end
