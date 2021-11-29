module Spree
  module Api
    module Webhooks
      module VariantDecorator
        def self.prepended(base)
          def base.custom_webhook_events
            %w[variant.back_in_stock variant.backorderable variant.discontinued variant.out_of_stock]
          end

          base.after_update_commit :queue_webhooks_requests_for_variant_discontinued!
        end

        private

        def queue_webhooks_requests_for_variant_discontinued!
          return unless discontinue_on_previously_changed?
          return if (change = discontinue_on_previous_change).blank? || change.last.blank?

          queue_webhooks_requests!('variant.discontinued')
        end
      end
    end
  end
end

Spree::Variant.prepend(Spree::Api::Webhooks::VariantDecorator)
