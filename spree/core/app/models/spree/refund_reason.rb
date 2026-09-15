module Spree
  # Why money went back — "Return processing", "Order Canceled". Store-owned
  # like {Spree::ReturnReason} and {Spree::ClaimReason}.
  class RefundReason < Spree.base_class
    has_prefix_id :rr

    include Spree::NamedType

    self.whitelisted_ransackable_attributes = %w[name active]

    RETURN_PROCESSING_REASON = 'Return processing'.freeze
    ORDER_CANCELED_REASON = 'Order Canceled'.freeze
    SHIPMENT_CANCELED_REASON = 'Shipment Canceled'.freeze

    has_many :refunds, class_name: 'Spree::Refund', dependent: :restrict_with_error

    # Mirrors what `dependent: :restrict_with_error` enforces, so the dashboard
    # can hide the delete control rather than offer one the model will refuse.
    #
    # @return [Boolean]
    def can_be_deleted?
      !refunds.exists?
    end

    class << self
      # The seeded reasons core attaches to refunds it issues itself.
      #
      # Each takes the store explicitly rather than reading
      # `Spree::Current.store`: these are called from workflows that already
      # hold the record's store, and a background job or console session has
      # no current store to fall back on — which would silently create the
      # reason against the wrong one.
      def return_processing_reason(store = Spree::Current.store)
        where(store: store).find_or_create_by(name: RETURN_PROCESSING_REASON)
      end

      def order_canceled_reason(store = Spree::Current.store)
        where(store: store).find_or_create_by(name: ORDER_CANCELED_REASON)
      end

      def shipment_canceled_reason(store = Spree::Current.store)
        where(store: store).find_or_create_by(name: SHIPMENT_CANCELED_REASON)
      end
    end
  end
end
