module Spree
  module Workflows
    # Base class for defining workflows
    # Provides a DSL for defining steps with compensation logic
    #
    # @example Define a simple workflow
    #   class OrderFulfillment < Spree::Workflows::Base
    #     workflow_id 'order_fulfillment'
    #
    #     step :validate_inventory do |input, context|
    #       order = Spree::Order.find(input[:order_id])
    #       StepResponse.success(order: order)
    #     end
    #
    #     step :reserve_inventory do |input, context|
    #       # Reserve stock
    #       StepResponse.success(
    #         { reserved: true },
    #         { items: reserved_items }  # compensation data
    #       )
    #     end.compensate do |data, context|
    #       # Restore inventory
    #     end
    #   end
    #
    # @example Run a workflow
    #   result = OrderFulfillment.run(input: { order_id: 123 }, store: current_store)
    #   result.success? # => true
    #
    # @example Define a workflow with hooks (for extensibility)
    #   class OrderFulfillment < Spree::Workflows::Base
    #     workflow_id 'order_fulfillment'
    #
    #     step :validate_order do |input, context|
    #       # ...
    #     end
    #
    #     # Define a hook point for extensions
    #     define_hook :after_order_validated
    #
    #     step :reserve_inventory do |input, context|
    #       # ...
    #     end
    #   end
    #
    #   # In an extension or initializer:
    #   Spree::OrderFulfillmentWorkflow.hooks.after_order_validated do |context|
    #     FraudService.check(context[:order])
    #   end.compensate do |context|
    #     FraudService.release_hold(context[:order])
    #   end
    #
    class Base
      include Hookable
      class << self
        attr_reader :defined_workflow_id

        # Set the workflow ID
        # @param id [String, Symbol] unique identifier for this workflow
        def workflow_id(id = nil)
          if id
            @defined_workflow_id = id.to_s
            Spree::Workflows.register(@defined_workflow_id, self)
          end
          @defined_workflow_id
        end

        # Get all defined steps
        # @return [Array<Step>]
        def steps
          @steps ||= []
        end

        # Get the sequence of steps and hooks in order
        # @return [Array<Step, Symbol>] steps and hook names in execution order
        def execution_sequence
          @execution_sequence ||= []
        end

        # Define a step in the workflow
        # @param id [String, Symbol] unique step identifier
        # @param options [Hash] step options
        # @option options [Boolean] :async wait for external signal
        # @option options [Array<Class>] :retry_on exceptions to retry
        # @option options [Integer] :max_retries maximum retries
        # @option options [Boolean] :batch use cursor-based batch processing
        # @yield [input, context] step logic
        # @return [Step] the created step for chaining .compensate
        def step(id, options = {}, &block)
          new_step = Step.new(id, options, &block)
          @steps ||= []
          @steps << new_step
          @execution_sequence ||= []
          @execution_sequence << new_step
          new_step
        end

        # Define a hook point in the workflow (called after the previous step)
        # @param name [Symbol] the hook name
        # @return [void]
        def define_hook(name)
          self.defined_hooks = defined_hooks + [name.to_sym]
          @execution_sequence ||= []
          @execution_sequence << { hook: name.to_sym }
        end

        # Run the workflow asynchronously (default)
        # @param input [Hash] initial input data
        # @param store [Spree::Store, nil] optional store context
        # @return [ExecutionResult] result wrapper with execution reference
        def run(input: {}, store: nil)
          execution = create_execution(input: input, store: store)

          Spree::Workflows::ExecuteWorkflowJob.perform_later(
            execution_id: execution.id
          )

          ExecutionResult.new(execution)
        end

        # Run the workflow synchronously (blocking)
        # @param input [Hash] initial input data
        # @param store [Spree::Store, nil] optional store context
        # @return [ExecutionResult] result wrapper
        def run_sync(input: {}, store: nil)
          execution = create_execution(input: input, store: store)

          Spree::Workflows::ExecuteWorkflowJob.new.perform(
            execution_id: execution.id
          )

          ExecutionResult.new(execution.reload)
        end

        # Find an existing execution
        # @param transaction_id [String] the transaction ID
        # @return [ExecutionResult, nil]
        def find_execution(transaction_id)
          execution = Spree::WorkflowExecution.find_by(
            workflow_id: defined_workflow_id,
            transaction_id: transaction_id
          )
          execution ? ExecutionResult.new(execution) : nil
        end

        # Find a step definition by ID
        # @param step_id [String] the step identifier
        # @return [Step, nil]
        def find_step(step_id)
          steps.find { |s| s.id == step_id.to_s }
        end

        private

        def create_execution(input:, store:)
          Spree::WorkflowExecution.create!(
            workflow_id: defined_workflow_id,
            transaction_id: SecureRandom.uuid,
            status: 'pending',
            input: input,
            context: {},
            store: store
          ).tap do |execution|
            # Pre-create step execution records
            steps.each_with_index do |step, index|
              execution.step_executions.create!(
                step_id: step.id,
                status: 'pending',
                position: index,
                async: step.async?
              )
            end
          end
        end
      end

      # Inherit steps and hooks when subclassing
      def self.inherited(subclass)
        super
        subclass.instance_variable_set(:@steps, steps.dup) if @steps
        subclass.instance_variable_set(:@execution_sequence, execution_sequence.dup) if @execution_sequence
      end
    end
  end
end
