module Spree
  class PaymentCaptureEvent < Spree.base_class
    has_prefix_id :pce

    belongs_to :payment, class_name: 'Spree::Payment'

    delegate :currency, to: :payment
  end
end
