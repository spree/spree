module Spree
  module Api
    module Webhooks
      module OrderDecorator
        def self.prepended(base)
          def base.custom_webhook_events
            %w[order.canceled order.placed order.resumed order.shipped]
          end
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
        end
      end
    end
  end
end

Spree::Order.prepend(Spree::Api::Webhooks::OrderDecorator)
