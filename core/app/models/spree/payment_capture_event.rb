module Spree
  class PaymentCaptureEvent < Spree.base_class
    belongs_to :payment, class_name: 'Spree::Payment'

    def display_amount
      Spree::Money.new(amount, currency: payment.currency)
    end
  end
end
