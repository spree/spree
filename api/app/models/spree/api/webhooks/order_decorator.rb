module Spree
  module Api
    module Webhooks
      module OrderDecorator
        def self.prepended(base)
          def base.custom_webhook_events
            %w[order.canceled order.placed order.resumed order.shipped]
          end

          base.after_update_commit :queue_webhooks_requests_for_order_resumed!
        end

        def after_cancel
          super
          queue_webhooks_requests!('order.canceled')
        end

        def finalize!
          super
          queue_webhooks_requests!('order.placed')
        end

        def after_resume
          super
          queue_webhooks_requests!('order.resumed')
          self.state_machine_resumed = false
        end

        private

        def queue_webhooks_requests_for_order_resumed!
          return if state_machine_resumed?
          return unless state_previously_changed?
          return unless state_previous_change&.last == 'resumed'

          queue_webhooks_requests!('order.resumed')
        end
      end
    end
  end
end

Spree::Order.prepend(Spree::Api::Webhooks::OrderDecorator)
