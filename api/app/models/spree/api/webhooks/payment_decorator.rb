module Spree
  module Api
    module Webhooks
      module PaymentDecorator
        def self.prepended(base)
          def base.custom_webhook_events
            %w[payment.paid payment.voided]
          end
        end

        def after_void
          super
          queue_webhooks_requests!('payment.voided')
        end

        def after_completed
          super
          queue_webhooks_requests!('payment.paid')
          order.queue_webhooks_requests!('order.paid') if order.paid?
        end
      end
    end
  end
end

Spree::Payment.prepend(Spree::Api::Webhooks::PaymentDecorator)
