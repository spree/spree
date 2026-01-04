module Spree
  module Workflows
    # Base error class for all workflow errors
    class Error < StandardError; end

    # Raised when a workflow is not found in the registry
    class WorkflowNotFoundError < Error; end

    # Raised when a step fails during execution
    class StepFailedError < Error
      attr_reader :step_id, :original_error, :compensation_data

      def initialize(message, step_id: nil, original_error: nil, compensation_data: nil)
        @step_id = step_id
        @original_error = original_error
        @compensation_data = compensation_data
        super(message)
      end
    end

    # Raised when a step returns a permanent failure (no retry)
    class PermanentFailureError < StepFailedError; end

    # Raised when a step should be retried
    # ActiveJob's retry_on handles this error with backoff
    class RetryableError < Error
      attr_reader :original_error

      def initialize(original_error)
        @original_error = original_error
        super(original_error.message)
      end
    end

    # Raised when trying to resume a workflow that cannot be resumed
    class WorkflowNotResumableError < Error; end

    # Raised when a step is not found in the workflow definition
    class StepNotFoundError < Error; end

    # Raised when workflow execution is already in progress
    class WorkflowAlreadyRunningError < Error; end

    # Raised when compensation fails
    class CompensationError < Error
      attr_reader :step_id, :original_error

      def initialize(message, step_id:, original_error: nil)
        @step_id = step_id
        @original_error = original_error
        super(message)
      end
    end
  end
end
