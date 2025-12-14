module Spree
  class Variant < Spree.base_class
    module Webhooks
      extend ActiveSupport::Concern
      include Spree::Webhooks::HasWebhooks

      included do
        after_update_commit :queue_webhooks_requests_for_variant_discontinued!
      end

      class_methods do
        def custom_webhook_events
          %w[variant.back_in_stock variant.backorderable variant.discontinued variant.out_of_stock]
        end
      end

      def queue_webhooks_requests_for_variant_discontinued!
        return unless discontinue_on_previously_changed?
        return if (change = discontinue_on_previous_change).blank? || change.last.blank?

        queue_webhooks_requests!('variant.discontinued')
      end
    end
  end
end
