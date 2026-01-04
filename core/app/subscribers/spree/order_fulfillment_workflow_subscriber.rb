module Spree
  # Subscriber that triggers the OrderFulfillmentWorkflow when an order is completed.
  #
  # This demonstrates how to use Spree::Workflows::Subscriber to bridge
  # the event system with workflows.
  #
  # @example The workflow is triggered automatically when 'order.completed' fires
  #   # When an order completes:
  #   order.complete!
  #   # This publishes 'order.completed' event
  #   # Which triggers OrderFulfillmentWorkflow.run(input: { order_id: order.id })
  #
  class OrderFulfillmentWorkflowSubscriber < Spree::Workflows::Subscriber
    subscribes_to 'order.completed'
    triggers_workflow 'order_fulfillment'

    # Only trigger for orders that need fulfillment
    def should_trigger?(event)
      # Skip digital-only orders (they don't need physical fulfillment)
      # This is just an example - customize based on your needs
      true
    end

    # Transform event payload to workflow input
    def build_input(event)
      {
        order_id: event.payload['id'],
        order_number: event.payload['number']
      }
    end

    # Called after workflow is triggered
    def after_workflow_triggered(event, result)
      Rails.logger.info(
        "[Workflow] OrderFulfillment triggered for order #{event.payload['number']}, " \
        "transaction_id: #{result.transaction_id}"
      )
    end
  end
end
