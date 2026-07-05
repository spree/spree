module Spree
  class PaymentCaptureEvent < Spree.base_class
    has_prefix_id :pce

    belongs_to :payment, class_name: 'Spree::Payment'

    def display_amount
      Spree::Money.new(amount, currency: payment.currency)
    end
  end
end
