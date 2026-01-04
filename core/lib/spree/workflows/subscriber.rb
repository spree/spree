module Spree
  module Workflows
    # A specialized subscriber that triggers a workflow when events occur.
    #
    # This bridges the Event system with the Workflow system, allowing you to
    # define workflows that are automatically triggered by specific events.
    #
    # @example Simple workflow subscriber
    #   class OrderFulfillmentSubscriber < Spree::Workflows::Subscriber
    #     subscribes_to 'order.completed'
    #     triggers_workflow 'order_fulfillment'
    #
    #     # Transform event payload to workflow input
    #     def build_input(event)
    #       { order_id: event.payload['id'] }
    #     end
    #   end
    #
    # @example With conditional triggering
    #   class HighValueOrderSubscriber < Spree::Workflows::Subscriber
    #     subscribes_to 'order.completed'
    #     triggers_workflow 'high_value_order_processing'
    #
    #     def should_trigger?(event)
    #       event.payload['total'].to_f > 1000
    #     end
    #
    #     def build_input(event)
    #       { order_id: event.payload['id'], priority: 'high' }
    #     end
    #   end
    #
    # @example Multiple events triggering different workflows
    #   class OrderLifecycleSubscriber < Spree::Workflows::Subscriber
    #     subscribes_to 'order.completed', 'order.canceled'
    #
    #     on 'order.completed', workflow: 'order_fulfillment'
    #     on 'order.canceled', workflow: 'order_cancellation'
    #
    #     def build_input(event)
    #       { order_id: event.payload['id'] }
    #     end
    #   end
    #
    # @example Workflow subscriber that waits for workflow completion
    #   class SyncOrderSubscriber < Spree::Workflows::Subscriber
    #     subscribes_to 'order.completed', async: false
    #     triggers_workflow 'order_fulfillment', mode: :sync
    #
    #     def build_input(event)
    #       { order_id: event.payload['id'] }
    #     end
    #   end
    #
    # Note: This class inherits from Spree::Subscriber which is autoloaded by Rails.
    # To ensure proper load order, we reference it directly here which triggers autoload.
    class Subscriber < ::Spree::Subscriber
      class << self
        # Declare which workflow this subscriber triggers
        #
        # @param workflow_id [String, Symbol] the workflow identifier
        # @param options [Hash] workflow options
        # @option options [Symbol] :mode (:async) :async or :sync execution
        # @return [void]
        def triggers_workflow(workflow_id, options = {})
          @triggered_workflow = workflow_id.to_s
          @workflow_options = options
        end

        # Map specific events to specific workflows
        #
        # @param pattern [String] event pattern
        # @param workflow [String] workflow to trigger
        # @param method_name [Symbol, nil] optional method to call
        def on(pattern, workflow: nil, method_name: nil)
          if workflow
            @event_workflows ||= {}
            @event_workflows[pattern.to_s] = workflow.to_s
          end

          super(pattern, method_name) if method_name
        end

        # Get the default workflow ID
        # @return [String, nil]
        def triggered_workflow
          @triggered_workflow
        end

        # Get workflow options
        # @return [Hash]
        def workflow_options
          @workflow_options || {}
        end

        # Get event-to-workflow mappings
        # @return [Hash<String, String>]
        def event_workflows
          @event_workflows || {}
        end
      end

      # Handle the event by triggering the appropriate workflow
      #
      # @param event [Spree::Event]
      def call(event)
        return unless should_trigger?(event)

        workflow_id = find_workflow_for_event(event)
        return unless workflow_id

        workflow_class = Spree::Workflows.find(workflow_id)
        input = build_input(event)
        store = find_store(event)
        metadata = build_metadata(event)

        result = execute_workflow(workflow_class, input, store, metadata)
        after_workflow_triggered(event, result)

        result
      rescue Spree::Workflows::WorkflowNotFoundError => e
        handle_workflow_not_found(event, e)
      end

      # Override to conditionally trigger the workflow
      #
      # @param event [Spree::Event]
      # @return [Boolean] whether to trigger the workflow
      def should_trigger?(event)
        true
      end

      # Override to transform event payload to workflow input
      #
      # @param event [Spree::Event]
      # @return [Hash] input for the workflow
      def build_input(event)
        event.payload.to_h.symbolize_keys
      end

      # Override to add custom metadata to the workflow
      #
      # @param event [Spree::Event]
      # @return [Hash] metadata to attach
      def build_metadata(event)
        {
          triggered_by_event: event.name,
          event_id: event.id,
          event_created_at: event.created_at
        }
      end

      # Override to handle successful workflow triggering
      #
      # @param event [Spree::Event]
      # @param result [Spree::Workflows::ExecutionResult]
      def after_workflow_triggered(event, result)
        # Override in subclass if needed
      end

      # Override to handle workflow not found errors
      #
      # @param event [Spree::Event]
      # @param error [Spree::Workflows::WorkflowNotFoundError]
      def handle_workflow_not_found(event, error)
        Rails.error.report(error, context: {
          event_name: event.name,
          event_id: event.id,
          subscriber: self.class.name
        })
      end

      private

      def find_workflow_for_event(event)
        # Check event-specific workflow mapping first
        event_workflows = self.class.event_workflows
        if event_workflows.present?
          event_workflows.each do |pattern, workflow_id|
            return workflow_id if event.matches?(pattern)
          end
        end

        # Fall back to default workflow
        self.class.triggered_workflow
      end

      def find_store(event)
        store_id = event.payload['store_id'] || event.metadata['store_id']
        Spree::Store.find_by(id: store_id) if store_id
      end

      def execute_workflow(workflow_class, input, store, metadata)
        options = self.class.workflow_options
        mode = options[:mode] || :async

        # Store metadata in input for now (could be enhanced later)
        input_with_metadata = input.merge(_event_metadata: metadata)

        if mode == :sync
          workflow_class.run_sync(input: input_with_metadata, store: store)
        else
          workflow_class.run(input: input_with_metadata, store: store)
        end
      end
    end
  end
end
