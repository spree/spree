module Spree
  module Products
    class QueueStatusChangedWebhookJob < Spree::BaseJob
      queue_as Spree.queues.webhooks

      def perform(product_id, event)
        product = Spree::Product.find(product_id)
        product.queue_webhooks_requests!("product.#{event}")
      end
    end
  end
end
