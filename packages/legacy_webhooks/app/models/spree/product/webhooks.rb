module Spree
  class Product < Spree.base_class
    module Webhooks
      extend ActiveSupport::Concern
      include Spree::Webhooks::HasWebhooks

      included do
        after_update_commit :queue_webhooks_requests_for_product_discontinued!
      end

      class_methods do
        def custom_webhook_events
          %w[product.back_in_stock product.backorderable product.discontinued
             product.out_of_stock product.activated product.archived product.drafted]
        end

        def ignored_attributes_for_update_webhook_event
          %w[status]
        end
      end

      def send_product_activated_webhook
        queue_webhooks_requests!('product.activated')
      end

      def send_product_archived_webhook
        queue_webhooks_requests!('product.archived')
      end

      def send_product_drafted_webhook
        queue_webhooks_requests!('product.drafted')
      end

      def queue_webhooks_requests_for_product_discontinued!
        return unless discontinue_on_previously_changed?
        return if (change = discontinue_on_previous_change).blank? || change.last.blank?

        queue_webhooks_requests!('product.discontinued')
      end
    end
  end
end
