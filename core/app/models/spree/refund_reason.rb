module Spree
  class RefundReason < Spree.base_class
    include Spree::NamedType

    RETURN_PROCESSING_REASON = 'Return processing'
    ORDER_CANCELED_REASON = 'Order Canceled'
    SHIPMENT_CANCELED_REASON = 'Shipment Canceled'

    has_many :refunds, dependent: :restrict_with_error

    def self.return_processing_reason
      find_or_create_by(name: RETURN_PROCESSING_REASON, mutable: false)
    end

    def self.order_canceled_reason
      find_or_create_by(name: ORDER_CANCELED_REASON, mutable: false)
    end

    def self.shipment_canceled_reason
      find_or_create_by(name: SHIPMENT_CANCELED_REASON, mutable: false)
    end
  end
end
