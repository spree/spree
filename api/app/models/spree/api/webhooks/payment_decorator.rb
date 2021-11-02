module Spree
  module Api
    module Webhooks
      module PaymentDecorator
        def after_void
          super
          queue_webhooks_requests!('payment.voided')
        end

        def after_completed
          super
          order.queue_webhooks_requests!('order.paid') if order.paid?
        end
      end
    end
  end
end

Spree::Payment.prepend(Spree::Api::Webhooks::PaymentDecorator)
