module Spree
  module Api
    module Webhooks
      module PaymentDecorator
        def after_void
          super
          queue_webhooks_requests!('payment.voided')
        end
      end
    end
  end
end

Spree::Payment.prepend(Spree::Api::Webhooks::PaymentDecorator)
