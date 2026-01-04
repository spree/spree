module Spree
  module Workflows
    # Job that executes workflow steps using Rails 8.1 ActiveJob::Continuable
    #
    # Uses ActiveJob features:
    # - Continuable: Steps can be interrupted and resumed across restarts
    # - retry_on: Automatic retries for transient errors with backoff
    #
    # Each workflow step becomes a Continuable step, allowing:
    # - Progress tracking across job restarts
    # - Cursor-based batch processing within steps
    # - Automatic checkpointing between steps
    #
    class ExecuteWorkflowJob < Spree::BaseJob
      include ActiveJob::Continuable

      queue_as { Spree.queues[:workflows] }

      # Retry transient errors with exponential backoff
      # These are infrastructure-level errors that may resolve on retry
      retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 5
      retry_on ActiveRecord::LockWaitTimeout, wait: :polynomially_longer, attempts: 5

      # Retry our custom retryable error (raised by steps that want retry)
      retry_on RetryableError, wait: ->(executions) { executions * 5 }, attempts: 5

      # Don't retry permanent failures - they should fail immediately
      discard_on PermanentFailureError

      # Main entry point for workflow execution
      # @param execution_id [Integer] the WorkflowExecution record ID
      def perform(execution_id:)
        @execution = Spree::WorkflowExecution.find(execution_id)
        @workflow_class = Spree::Workflows.find(@execution.workflow_id)
        @context = (@execution.context || {}).with_indifferent_access
        @executed_hooks = []

        return if already_finished?

        mark_running

        # Execute each item in the workflow sequence as a Continuable step
        @workflow_class.execution_sequence.each_with_index do |item, index|
          if item.is_a?(Hash) && item[:hook]
            # Hooks are lightweight, execute inline
            step :"hook_#{item[:hook]}" do
              execute_hook(item[:hook])
            end
          else
            # Workflow steps get their own Continuable step
            workflow_step = item
            step workflow_step.id.to_sym do |continuable_step|
              execute_workflow_step(workflow_step, continuable_step)
            end
          end
        end

        mark_completed
      rescue StepFailedError => e
        handle_step_failure(e)
      rescue PermanentFailureError => e
        handle_step_failure(e)
      rescue StandardError => e
        handle_unexpected_failure(e)
      end

      private

      def already_finished?
        @execution.completed? || @execution.compensated?
      end

      def mark_running
        return unless @execution.pending? || @execution.waiting?

        @execution.update!(status: 'running', started_at: Time.current) if @execution.started_at.nil?
      end

      def execute_hook(hook_name)
        handler = @workflow_class.hook_handler_for(hook_name)
        return unless handler

        @executed_hooks << hook_name
        handler.execute(@context)
      rescue HookExecutionError => e
        raise StepFailedError.new(
          e.message,
          step_id: "hook:#{hook_name}",
          original_error: e.original_error
        )
      end

      def execute_workflow_step(workflow_step, continuable_step)
        step_execution = find_or_create_step_execution(workflow_step)
        @execution.update!(current_step_id: workflow_step.id)

        # Skip already completed steps (for resumed workflows)
        return if step_execution.completed?

        # Handle async steps - they pause and wait for external signal
        if workflow_step.async?
          handle_async_step(workflow_step, step_execution)
          return
        end

        # Execute the step
        run_step(workflow_step, step_execution, continuable_step)
      end

      def find_or_create_step_execution(workflow_step)
        @execution.step_executions.find_or_create_by!(step_id: workflow_step.id) do |se|
          se.status = 'pending'
          se.async = workflow_step.async?
          se.attempts = 0
        end
      end

      def handle_async_step(workflow_step, step_execution)
        if step_execution.pending?
          step_execution.mark_running!
          @execution.update!(status: 'waiting', current_step_id: workflow_step.id)
          throw :abort # Stop job execution, wait for Engine.complete_step
        elsif step_execution.running?
          # Still waiting for external completion
          @execution.update!(status: 'waiting')
          throw :abort
        end
        # If completed, continue to next step
      end

      def run_step(workflow_step, step_execution, continuable_step)
        step_execution.mark_running!
        step_execution.increment!(:attempts)

        # Build input from original input + accumulated context
        input = (@execution.input || {}).merge(@context.to_h)

        # Execute with cursor support for batch processing
        response = if workflow_step.batch?
                     workflow_step.execute(input, @context, cursor: continuable_step.cursor)
                   else
                     workflow_step.execute(input, @context)
                   end

        handle_step_response(workflow_step, step_execution, response, continuable_step)
      end

      def handle_step_response(workflow_step, step_execution, response, continuable_step)
        case response
        when StepResponse
          complete_step(step_execution, response)

          # For batch steps, check if there's more work via cursor
          if workflow_step.batch? && response.output[:next_cursor]
            continuable_step.advance! from: response.output[:next_cursor]
            # Re-run this step with new cursor on next iteration
            step_execution.update!(status: 'pending')
          end

        when FailedStepResponse
          step_execution.mark_failed!(StandardError.new(response.error))
          raise StepFailedError.new(
            response.error,
            step_id: workflow_step.id,
            compensation_data: response.compensation_data
          )

        when PermanentFailureResponse
          step_execution.mark_failed!(StandardError.new(response.error))
          raise PermanentFailureError.new(
            response.error,
            step_id: workflow_step.id,
            compensation_data: response.compensation_data
          )
        end
      end

      def complete_step(step_execution, response)
        step_execution.mark_completed!(
          output: response.output,
          compensation_data: response.compensation_data
        )

        # Merge output into context for subsequent steps
        @context.merge!(response.output) if response.output.is_a?(Hash)
        @execution.update!(context: @context)
      end

      def handle_step_failure(error)
        failed_step = @execution.step_executions.find_by(step_id: error.step_id) if error.respond_to?(:step_id)
        failed_step&.mark_failed!(error)

        run_compensations

        @execution.update!(
          status: 'failed',
          error_message: error.message,
          error_class: error.class.name,
          completed_at: Time.current
        )

        publish_event(:failed, error: error.message)
      end

      def handle_unexpected_failure(error)
        current_step = @execution.step_executions.find_by(step_id: @execution.current_step_id)
        current_step&.mark_failed!(error)

        run_compensations

        @execution.update!(
          status: 'failed',
          error_message: error.message,
          error_class: error.class.name,
          completed_at: Time.current
        )

        Rails.error.report(error, context: error_context)
        publish_event(:failed, error: error.message)
      end

      def run_compensations
        @execution.update!(status: 'compensating')

        # Compensate hooks in reverse order first
        compensate_hooks

        # Then compensate steps in reverse order
        @execution.step_executions.needs_compensation.each do |step_execution|
          compensate_step(step_execution)
        end

        @execution.update!(status: 'compensated') if @execution.compensating?
      end

      def compensate_hooks
        @executed_hooks.reverse_each do |hook_name|
          handler = @workflow_class.hook_handler_for(hook_name)
          next unless handler&.compensatable?

          handler.compensate(@context)
        rescue StandardError => e
          Rails.error.report(e, context: error_context.merge(hook: hook_name))
        end
      end

      def compensate_step(step_execution)
        workflow_step = @workflow_class.find_step(step_execution.step_id)
        return unless workflow_step&.compensatable?

        compensation_data = step_execution.compensation_data || {}
        workflow_step.compensate!(compensation_data, @context)
        step_execution.mark_compensated!
      rescue StandardError => e
        step_execution.mark_compensation_failed!(e)
        Rails.error.report(e, context: error_context.merge(step_id: step_execution.step_id))
      end

      def mark_completed
        @execution.update!(
          status: 'completed',
          output: @context,
          completed_at: Time.current
        )

        publish_event(:completed, output: @context)
      end

      def publish_event(type, data = {})
        Engine.publish(
          transaction_id: @execution.transaction_id,
          type: type,
          data: data
        )
      end

      def error_context
        {
          workflow_id: @execution.workflow_id,
          transaction_id: @execution.transaction_id,
          execution_id: @execution.id
        }
      end
    end
  end
end
