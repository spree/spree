module Spree
  module Workflows
    # Engine provides an API for managing workflow executions
    # - Complete async steps
    # - Fail async steps
    # - Subscribe to workflow events
    # - Query execution status
    module Engine
      class << self
        # Complete an async step with output data
        # This resumes the workflow from where it was waiting
        #
        # @param transaction_id [String] the workflow transaction ID
        # @param step_id [String] the step to complete
        # @param output [Hash] the output data for this step
        # @return [ExecutionResult] the updated execution result
        # @raise [WorkflowNotFoundError] if workflow not found
        # @raise [StepNotFoundError] if step not found
        # @raise [WorkflowNotResumableError] if workflow cannot be resumed
        def complete_step(transaction_id:, step_id:, output: {})
          execution = find_execution!(transaction_id)
          step_execution = find_step_execution!(execution, step_id)

          validate_can_complete!(execution, step_execution)

          # Mark the step as completed
          step_execution.mark_completed!(
            output: output,
            compensation_data: output
          )

          # Update context with step output
          context = (execution.context || {}).merge(output)
          execution.update!(context: context)

          # Resume workflow execution
          ExecuteWorkflowJob.perform_later(execution_id: execution.id)

          ExecutionResult.new(execution.reload)
        end

        # Fail an async step with an error
        # This triggers compensation for completed steps
        #
        # @param transaction_id [String] the workflow transaction ID
        # @param step_id [String] the step that failed
        # @param error [String] the error message
        # @param compensation_data [Hash] optional data for compensation
        # @return [ExecutionResult] the updated execution result
        def fail_step(transaction_id:, step_id:, error:, compensation_data: nil)
          execution = find_execution!(transaction_id)
          step_execution = find_step_execution!(execution, step_id)

          validate_can_complete!(execution, step_execution)

          # Store compensation data if provided
          step_execution.update!(compensation_data: compensation_data) if compensation_data

          # Mark step as failed
          step_execution.mark_failed!(StandardError.new(error))

          # Trigger compensation via the job
          execution.update!(status: 'failed', error_message: error)
          ExecuteWorkflowJob.perform_later(execution_id: execution.id)

          ExecutionResult.new(execution.reload)
        end

        # Retry a failed workflow from the failed step
        #
        # Use this for manual intervention after automatic retries are exhausted.
        # The workflow will resume from the failed step.
        #
        # @param transaction_id [String] the workflow transaction ID
        # @return [ExecutionResult] the updated execution result
        # @raise [WorkflowNotResumableError] if workflow is not in failed state
        def retry(transaction_id:)
          execution = find_execution!(transaction_id)

          unless execution.failed? || execution.compensated?
            raise WorkflowNotResumableError, "Cannot retry workflow in status '#{execution.status}'"
          end

          # Reset failed steps to pending
          execution.step_executions.where(status: %w[failed compensation_failed]).find_each do |step|
            step.update!(
              status: 'pending',
              error_message: nil,
              error_class: nil,
              started_at: nil,
              completed_at: nil,
              attempts: 0
            )
          end

          # Reset workflow status
          execution.update!(
            status: 'pending',
            error_message: nil,
            error_class: nil,
            completed_at: nil
          )

          # Re-execute via ActiveJob
          ExecuteWorkflowJob.perform_later(execution_id: execution.id)

          ExecutionResult.new(execution.reload)
        end

        # Cancel a running or waiting workflow
        # Triggers compensation for any completed steps
        #
        # @param transaction_id [String] the workflow transaction ID
        # @param reason [String] optional cancellation reason
        # @return [ExecutionResult] the updated execution result
        def cancel(transaction_id:, reason: 'Cancelled by user')
          execution = find_execution!(transaction_id)

          unless execution.running? || execution.waiting? || execution.pending?
            raise WorkflowNotResumableError, "Cannot cancel workflow in status '#{execution.status}'"
          end

          # Mark as failed to trigger compensation
          execution.update!(
            status: 'failed',
            error_message: reason
          )

          # Skip any pending/running steps
          execution.step_executions.where(status: %w[pending running]).update_all(status: 'skipped')

          # Run compensation via job
          ExecuteWorkflowJob.perform_later(execution_id: execution.id)

          ExecutionResult.new(execution.reload)
        end

        # Subscribe to workflow events
        # The subscriber will be called when the workflow reaches certain states
        #
        # @param transaction_id [String] the workflow transaction ID
        # @param subscriber_id [String] unique identifier for this subscriber
        # @yield [event] block called with event data
        # @yieldparam event [Hash] event with :type, :workflow_id, :transaction_id, :data
        #
        # @example
        #   Engine.subscribe(transaction_id: 'xxx', subscriber_id: 'my-handler') do |event|
        #     case event[:type]
        #     when :completed then notify_user(event[:data][:output])
        #     when :failed then alert_admin(event[:data][:error])
        #     end
        #   end
        def subscribe(transaction_id:, subscriber_id:, &block)
          subscriptions[transaction_id] ||= {}
          subscriptions[transaction_id][subscriber_id] = block
        end

        # Unsubscribe from workflow events
        #
        # @param transaction_id [String] the workflow transaction ID
        # @param subscriber_id [String] the subscriber to remove
        def unsubscribe(transaction_id:, subscriber_id:)
          subscriptions[transaction_id]&.delete(subscriber_id)
          subscriptions.delete(transaction_id) if subscriptions[transaction_id]&.empty?
        end

        # Publish an event to subscribers (called internally by the job)
        #
        # @param transaction_id [String] the workflow transaction ID
        # @param type [Symbol] event type (:step_completed, :completed, :failed, :waiting)
        # @param data [Hash] event data
        def publish(transaction_id:, type:, data: {})
          return unless subscriptions[transaction_id]

          event = {
            type: type,
            transaction_id: transaction_id,
            data: data,
            timestamp: Time.current
          }

          subscriptions[transaction_id].each_value do |subscriber|
            safely_call_subscriber(subscriber, event)
          end
        end

        # Get the status of a workflow execution
        #
        # @param transaction_id [String] the workflow transaction ID
        # @return [ExecutionResult, nil]
        def status(transaction_id:)
          execution = Spree::WorkflowExecution.find_by(transaction_id: transaction_id)
          execution ? ExecutionResult.new(execution) : nil
        end

        # List all executions for a workflow
        #
        # @param workflow_id [String] the workflow identifier
        # @param status [String, nil] optional status filter
        # @param limit [Integer] max results
        # @return [Array<ExecutionResult>]
        def list_executions(workflow_id:, status: nil, limit: 100)
          scope = Spree::WorkflowExecution.for_workflow(workflow_id)
          scope = scope.where(status: status) if status
          scope.order(created_at: :desc).limit(limit).map { |e| ExecutionResult.new(e) }
        end

        # Clean up old completed/failed executions
        #
        # @param older_than [ActiveSupport::Duration] age threshold
        # @param statuses [Array<String>] statuses to clean
        # @return [Integer] number of deleted records
        def cleanup(older_than: 30.days, statuses: %w[completed failed compensated])
          Spree::WorkflowExecution
            .where(status: statuses)
            .where(created_at: ...older_than.ago)
            .destroy_all
            .count
        end

        private

        def subscriptions
          @subscriptions ||= {}
        end

        def find_execution!(transaction_id)
          Spree::WorkflowExecution.find_by!(transaction_id: transaction_id)
        rescue ActiveRecord::RecordNotFound
          raise WorkflowNotFoundError, "Workflow execution '#{transaction_id}' not found"
        end

        def find_step_execution!(execution, step_id)
          execution.step_executions.find_by!(step_id: step_id)
        rescue ActiveRecord::RecordNotFound
          raise StepNotFoundError, "Step '#{step_id}' not found in workflow"
        end

        def validate_can_complete!(execution, step_execution)
          unless execution.waiting?
            raise WorkflowNotResumableError, "Workflow is not waiting (status: #{execution.status})"
          end

          unless step_execution.running? && step_execution.async?
            raise WorkflowNotResumableError, "Step '#{step_execution.step_id}' is not an async step waiting for completion"
          end
        end

        def safely_call_subscriber(subscriber, event)
          subscriber.call(event)
        rescue StandardError => e
          Rails.error.report(e, context: { event: event })
        end
      end
    end
  end
end
