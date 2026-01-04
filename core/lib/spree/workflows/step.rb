module Spree
  module Workflows
    # Execution context for step blocks, providing DSL helpers
    # This allows steps to call `success`, `failure`, and `retry!` directly
    #
    # @attr_reader input [HashWithIndifferentAccess] input data from previous steps
    # @attr_reader context [HashWithIndifferentAccess] shared workflow context
    class StepExecutionContext
      attr_reader :input, :context

      def initialize(input, context)
        @input = input.is_a?(Hash) ? input.with_indifferent_access : input
        @context = context.is_a?(Hash) ? context.with_indifferent_access : context
      end

      # Create a successful step response
      # @param output [Hash] the output data to pass to subsequent steps
      # @param compensation_data [Hash, nil] data for rollback (defaults to output)
      # @return [StepResponse]
      def success(output = {}, compensation_data = nil)
        StepResponse.success(output, compensation_data)
      end

      # Create a failed step response (will trigger compensation)
      # @param error [String, Exception] error message
      # @param compensation_data [Hash, nil] data for rollback
      # @return [FailedStepResponse]
      def failure(error, compensation_data = nil)
        StepResponse.failure(error, compensation_data)
      end

      # Create a permanent failure (no retry, triggers compensation)
      # @param error [String, Exception] error message
      # @param compensation_data [Hash, nil] data for rollback
      # @return [PermanentFailureResponse]
      def permanent_failure(error, compensation_data = nil)
        StepResponse.permanent_failure(error, compensation_data)
      end

      # Signal that this step should be retried
      # ActiveJob will handle the retry with backoff
      # @param error [String, Exception] error message or exception
      # @raise [RetryableError] always raises to trigger ActiveJob retry
      def retry!(error)
        exception = error.is_a?(Exception) ? error : StandardError.new(error.to_s)
        raise RetryableError.new(exception)
      end
    end

    # Represents a single step in a workflow
    #
    # Steps have a handler (the main logic) and optional compensation (rollback logic).
    # Retries are handled by ActiveJob's retry_on mechanism.
    #
    # @example Simple step
    #   step :process_order do |input, context|
    #     order = Order.find(input[:order_id])
    #     success({ order_id: order.id })
    #   end
    #
    # @example Step with compensation
    #   step :reserve_inventory do |input, context|
    #     # ... reserve logic
    #     success({ reserved: true }, { item_ids: item_ids })
    #   end.compensate do |data, context|
    #     # ... rollback logic using data[:item_ids]
    #   end
    #
    # @example Step that requests retry on transient error
    #   step :call_external_api do |input, context|
    #     response = ExternalAPI.call(input[:data])
    #     success({ response: response })
    #   rescue Net::TimeoutError => e
    #     retry!(e) # Will be retried by ActiveJob
    #   end
    #
    # @example Async step (waits for external signal)
    #   step :wait_for_payment, async: true do |input, context|
    #     # This runs when Engine.complete_step is called
    #     success({ payment_confirmed: true })
    #   end
    #
    # @example Batch step with cursor
    #   step :process_items, batch: true do |input, context, cursor|
    #     items = Item.where("id > ?", cursor || 0).limit(100)
    #     items.each { |item| process(item) }
    #     success({ processed: items.size, next_cursor: items.last&.id })
    #   end
    #
    class Step
      attr_reader :id, :options, :handler, :compensation_handler

      # Create a new step
      # @param id [String, Symbol] unique identifier for the step
      # @param options [Hash] step configuration options
      # @option options [Boolean] :async whether this step waits for external signal
      # @option options [Boolean] :batch whether this step processes items in batches with cursor
      # @param handler [Proc] the step logic to execute
      def initialize(id, options = {}, &handler)
        @id = id.to_s
        @options = options.with_indifferent_access
        @handler = handler
        @compensation_handler = nil
      end

      # Define compensation (rollback) logic for this step
      # @yield [compensation_data, context] block to execute on rollback
      # @return [Step] self for chaining
      def compensate(&block)
        @compensation_handler = block
        self
      end

      # Check if this step is async (waits for external signal)
      # @return [Boolean]
      def async?
        @options[:async] == true
      end

      # Check if this step processes batches with cursor
      # @return [Boolean]
      def batch?
        @options[:batch] == true
      end

      # Check if this step has compensation logic
      # @return [Boolean]
      def compensatable?
        @compensation_handler.present?
      end

      # Execute the step handler
      # @param input [Hash] input data from previous steps
      # @param context [HashWithIndifferentAccess] shared workflow context
      # @param cursor [Object, nil] cursor for batch processing (from ActiveJob::Continuable)
      # @return [StepResponse] the step result
      def execute(input, context, cursor: nil)
        # Create execution context with DSL helpers (success, failure, retry!, etc.)
        exec_context = StepExecutionContext.new(input, context)

        result = if batch? && cursor
                   exec_context.instance_exec(input, context, cursor, &@handler)
                 else
                   exec_context.instance_exec(input, context, &@handler)
                 end

        # Normalize the result to a StepResponse
        case result
        when StepResponse, FailedStepResponse, PermanentFailureResponse
          result
        when Hash
          StepResponse.success(result)
        else
          StepResponse.success({ result: result })
        end
      rescue RetryableError
        # Let ActiveJob handle retries
        raise
      rescue StandardError => e
        raise StepFailedError.new(
          e.message,
          step_id: @id,
          original_error: e
        )
      end

      # Execute compensation logic
      # @param compensation_data [Hash] data saved from the original execution
      # @param context [Context] shared workflow context
      def compensate!(compensation_data, context)
        return unless @compensation_handler

        compensation_data = compensation_data.with_indifferent_access if compensation_data.is_a?(Hash)
        @compensation_handler.call(compensation_data, context)
      rescue StandardError => e
        raise CompensationError.new(
          "Compensation failed for step '#{@id}': #{e.message}",
          step_id: @id,
          original_error: e
        )
      end
    end
  end
end
