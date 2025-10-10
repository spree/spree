module Spree
  class PaymentCaptureEvent < Spree.base_class
    if defined?(Spree::Webhooks::HasWebhooks)
      include Spree::Webhooks::HasWebhooks
    end

    belongs_to :payment, class_name: 'Spree::Payment'

    def display_amount
      Spree::Money.new(amount, currency: payment.currency)
    end
  end
end
